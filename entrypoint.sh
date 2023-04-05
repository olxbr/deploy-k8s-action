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
  BASIC_TOKEN=$(jq -r ".auths.\"$DOMAIN\".auth" ~/.docker/config.json 2> /dev/null || echo null)

  if [[ $BASIC_TOKEN != null ]]; then
      status_code=$(curl -s -H "Authorization: Basic $BASIC_TOKEN" --write-out '%{http_code}' -o /dev/null https://$DOMAIN/v2/_catalog)
      if [[ $status_code == 200 ]]; then
          _log info "Auth token is valid. Checking if image exits [$IMAGE] ..."

          docker manifest inspect $IMAGE > /dev/null 2>&1 &&
              _log info "Image FOUND on registry [$IMAGE]. Proceed to deploy..." ||
              (_log erro "Image NOT FOUND on registry [$IMAGE]. Check if image has been pushed to registry."; exit 1)

      else
          _log warn "Auth token has expired. Unable to check image on registry [$DOMAIN]."
      fi
  else
      _log warn "Auth token not found on config file for domain [$DOMAIN]. Skipping process to check if image exists on registry."
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


## Force restart
if [ "${FORCE_RESTART}" = true ] ; then
    kubectl -n $NAMESPACE \
        rollout restart deployment/$DEPLOYMENT_NAME \
        -s $K8S_CLUSTER \
        --token=$K8S_TOKEN \
        --insecure-skip-tls-verify
fi

## Vulnerabilty scans
SCANS=$(ls ${GITHUB_ACTION_PATH}/security/*.sh)
for SCAN in $SCANS; do
    _log info "Executing scan script $SCAN"
    $SCAN
    echo "================="
    echo ""
done
