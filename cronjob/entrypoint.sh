#!/bin/bash

set -e

if [ -z "$VERSION" ]; then
  echo "VERSION should not be empty. Exiting with error."
  exit 1
fi

sed -i -e "s/\${version}/$VERSION/" k8s/cronjobs/$ENVIRONMENT/*.yml
sed -i -e "s/\${environment}/$ENVIRONMENT/" k8s/cronjobs/$ENVIRONMENT/*.yml
sed -i -e "s/\${container-registry-host}/$CONTAINER_REGISTRY_HOST/" k8s/cronjobs/$ENVIRONMENT/*.yml

## apply cronjob
kubectl -n $NAMESPACE \
  apply -s $K8S_CLUSTER \
  --token=$K8S_TOKEN \
  -f k8s/$ENVIRONMENT --recursive \
  --insecure-skip-tls-verify || exit 1

## check if cronjob was successfully applied or not
kubectl -n $NAMESPACE \
  get cronJob $CRONJOB_NAME \
  -s $K8S_CLUSTER \
  --token=$K8S_TOKEN \
  --insecure-skip-tls-verify