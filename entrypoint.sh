#!/bin/bash

set -e

if [ -z "$VERSION" ]; then
  echo "VERSION should not be empty. Exiting with error."
  exit 1
fi

sed -i '' "s/\${version}/$VERSION/" deploy/$ENVIRONMENT/*.yml
sed -i '' "s/\${version}/$VERSION/" deploy/$ENVIRONMENT/*.yaml
sed -i '' "s/\${environment}/$ENVIRONMENT/" deploy/$ENVIRONMENT/*.yml
sed -i '' "s/\${environment}/$ENVIRONMENT/" deploy/$ENVIRONMENT/*.yaml

## apply deployment
kubectl -n $NAMESPACE \
  apply --record -s $K8S_CLUSTER \
  --token=$K8S_TOKEN \
  -f  deploy/$ENVIRONMENT --recursive \
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
  -f deploy/$ENVIRONMENT --recursive \
  --insecure-skip-tls-verify; exit 1; }
