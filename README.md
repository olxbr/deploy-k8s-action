# deploy-k8s-action
Action to deploy application on Kubernetes.

## Usage

```yaml
# .github/workflows/my-workflow.yml
jobs:
    my_job:
        ...
        runs-on: [self-hosted, ...]
        steps:
            - id: deploy-k8s
              uses: olxbr/deploy-k8s-action@v1
              with:
                # Don't change this value
                container-registry-host: ${{ secrets.CONTAINER_REGISTRY_HOST }}
                # Create cluster and token secrets inside your repository
                k8s-cluster: ${{ secrets.CLUSTER_PROD }}
                k8s-token: ${{ secrets.CLUSTER_GH_TOKEN }}
                deployment-name: deployment-name
                # Same inside of k8s folder like prod, qa and etc...
                environment: prod
                namespace: cluster-namespace
                # Docker image version that will be replaced in deployment.yml
                version: ${{ needs.build-n-push-docker-img.outputs.tag }}
                # Set true if deployment does not require a rollout status check
                # It's not required!
                skip-rollout-check: false

            - ... other steps
```

## Prerequisites

### Runner Self-Hosted
You have to use the **self-hosted runner** to deploy your app in the specific environment.

### Kubernetes cluster URL and TOKEN
We suggest adding **cluster url** and **token** as repository secret.

### Deployment folder
In the root directory, create the **k8s** folder with the following structure:

```
- k8s
    - prod/
        - service.yml
        - deployment.yml
        - etc...

    - qa/
        - service.yml
        - deployment.yml
        - etc...

    - other-environments/
        - manifest.yml
```

### Deployment file with vars to replace in action
The action replaces the vars **${version}**, **${environment}** and **${container-registry-host}** inside of **all manifest yml** in *k8s/{environment}/* folder.

- **version:** Commonly used to identify the version of the Docker image.
- **environment:** Only if you deem it necessary.
- **container-registry-host** Container registry host, for exemple: `xxxx.dkr.ecr.us-east-1.amazonaws.com`.
- **skip-rollout-check** Set true if deployment does not require a rollout status check.
