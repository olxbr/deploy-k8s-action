#!/bin/bash

# Pre-requisite: install the trivy, kubectl and jq
# https://aquasecurity.github.io/trivy/v0.18.3/installation/
# https://kubernetes.io/docs/tasks/tools/
# https://stedolan.github.io/jq/download/

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

K8S_SERVICES=("deployments" "cronjobs")

TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%SZ')
SEVERITY="CRITICAL"

echo "Starting scan..."
for K8S_SERVICE in "${K8S_SERVICES[@]}"; do
    # Getting all images by namespace and k8s service
    _log info "Getting all images by namespace and k8s service"
    if [ "${K8S_SERVICE}" == "deployments" ]; then
        IMGS=$(kubectl get deployments --token=${K8S_TOKEN} -n ${NAMESPACE} -o jsonpath='{.items[*].spec.template.spec.containers[*].image}')
    else
        IMGS=$(kubectl -n ${NAMESPACE} get ${K8S_SERVICE} --token=${K8S_TOKEN} -o jsonpath='{.items[*].spec.jobTemplate.spec.template.spec.containers[*].image}')
    fi

    # Redefine myvar to myarray using parenthesis
    _log info "Redefine myvar to myarray using parenthesis"
    IMAGE_ARRAY=($IMGS)

    _log info "Starting scan of images"
    for IMAGE in "${IMAGE_ARRAY[@]}"; do
        _log info "The image will be $IMAGE"
        SCAN_IMG_TEMP_FILE="temp-scan-result.json"
        APPLICATION_NAME=$(echo "${IMAGE}" | cut -d '/' -f2 | cut -d ':' -f1)
        OUTPUT_FILE="${NAMESPACE}-${K8S_SERVICE}-${APPLICATION_NAME}-trivy-result.json"
        _log info "The output file will be $OUTPUT_FILE"
        _log info "Scanning application ${APPLICATION_NAME} by image ${IMAGE} from namespace ${NAMESPACE} and k8s service ${K8S_SERVICE}"
        ${GITHUB_ACTION_PATH}/security/trivy_v0_21_3_Linux_64bit image --no-progress --light -f json -o "${SCAN_IMG_TEMP_FILE}" --severity "${SEVERITY}" "${IMAGE}" && cat "${SCAN_IMG_TEMP_FILE}" | jq ". | {Namespace: \"${NAMESPACE}\", K8sService: \"${K8S_SERVICE}\", ApplicationName: \"${APPLICATION_NAME}\", ArtifactName: .ArtifactName, Timestamp: \"${TIMESTAMP}\", Results: .Results | [.[]? | {Target: .Target, Vulnerabilities: .Vulnerabilities | [.[]? | {VulnerabilityID: .VulnerabilityID?, Severity: .Severity?, PkgName: .PkgName?, InstalledVersion: .InstalledVersion?, InstalledVersion: .InstalledVersion?, FixedVersion: .FixedVersion?}]}]}" >> "${OUTPUT_FILE}" && rm "${SCAN_IMG_TEMP_FILE}"
    done
done
printf  "\n"
