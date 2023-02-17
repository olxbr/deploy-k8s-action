#!/bin/bash

set -e

## Colors
ESC_SEQ="\x1b["
C_RESET=$ESC_SEQ"39;49;00m"
C_BOLD=$ESC_SEQ"39;49;01m"
C_RED=$ESC_SEQ"31;01m"
C_YEL=$ESC_SEQ"33;01m"

function _log() {
    case $1 in
      erro) logLevel="${C_RED}[ERRO]${C_RESET}";;
      warn) logLevel="${C_YEL}[WARN]${C_RESET}";;
      *)    logLevel="${C_BOLD}[INFO]${C_RESET}";;
    esac

    echo -e "$(date +"%d-%b-%Y %H:%M:%S") ${logLevel} - ${2}"
}

if [ -z "$VERSION" ]; then
  _log erro  "VERSION should not be empty. Exiting with error."
  exit 1
fi

sed -i -e "s/\${version}/$VERSION/" k8s/$ENVIRONMENT/*.y*ml
sed -i -e "s/\${environment}/$ENVIRONMENT/" k8s/$ENVIRONMENT/*.y*ml
sed -i -e "s/\${container-registry-host}/$CONTAINER_REGISTRY_HOST/" k8s/$ENVIRONMENT/*.y*ml

# If docker is authenticated, check image before
LIST_IMAGES=($(grep image: k8s/$ENVIRONMENT/*.y*ml | grep -v "#" | cut -d: -f2-))

for IMAGE in ${LIST_IMAGES[@]}; do
  DOMAIN=$(cut -d/ -f1 <<< $IMAGE)
  _log info "Checking if docker is authenticated on domain $DOMAIN..."

  if grep -q $DOMAIN ~/.docker/config.json; then
    _log info "Checking if image [$IMAGE] exits..."
    docker manifest inspect $IMAGE > /dev/null 2>&1 &&
      _log info "Image [$IMAGE] FOUND. Proceed to deploy..." ||
      _log erro "Image [$IMAGE] NOT FOUND on Registry. Check if image has been pushed to registry."
  else
    _log warn "Domain [$DOMAIN] is not authenticated. Skipping process to check if image exists on Registry."
  fi
done

## apply deployment
kubectl -n $NAMESPACE \
  apply -s $K8S_CLUSTER \
  --token=$K8S_TOKEN \
  -f k8s/$ENVIRONMENT --recursive \
  --insecure-skip-tls-verify || exit 1

if [ "$SKIP_ROLLOUT_CHECK" = true ] ; then
  exit 0;
fi

## check if the deploy was successful or not
kubectl -n $NAMESPACE \
  rollout status deployment/$DEPLOYMENT_NAME \
  -s $K8S_CLUSTER \
  --token=$K8S_TOKEN \
  --insecure-skip-tls-verify || {
## if failed then undo it
kubectl -n $NAMESPACE \
  rollout undo \
  -s $K8S_CLUSTER \
  --token=$K8S_TOKEN \
  -f k8s/$ENVIRONMENT --recursive \
  --insecure-skip-tls-verify; exit 1; }

## Vulnerabilty scans
SCANS=$(ls ${GITHUB_ACTION_PATH}/security/*.sh)
for SCAN in $SCANS; do
    _log info "Executing scan script $SCAN"
    $SCAN
    echo "================="
    echo ""
done
