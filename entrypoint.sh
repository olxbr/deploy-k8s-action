#!/bin/bash

set -e

if [ -z "$VERSION" ]; then
  echo "VERSION should not be empty. Exiting with error."
  exit 1
fi

config_file=k8s-$ENVIRONMENT-$VERSION.yml

sed "s/\${version}/$VERSION/" deploy/$ENVIRONMENT/deployment.yml > $config_file
sed "s/\${environment}/$ENVIRONMENT/" deploy/$ENVIRONMENT/deployment.yml > $config_file

## apply deployment
kubectl -n $NAMESPACE \
  apply --record -s $K8S_CLUSTER \
  --token=$K8S_TOKEN \
  -f $config_file \
  --insecure-skip-tls-verify || exit 1

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
  -f $config_file \
  --insecure-skip-tls-verify; exit 1; }
