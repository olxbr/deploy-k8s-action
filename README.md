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
                k8s-cluster: ${{ secrets.CLUSTER_PROD }}
                k8s-token: ${{ secrets.CLUSTER_GH_TOKEN }}
                deployment-name: deployment-name
                # Same inside of deploy folder like prod, qa and etc...
                environment: prod
                namespace: cluster-namespace
                # Docker image version that will be replaced in deployment.yml
                version: ${{ needs.build-n-push-docker-img.outputs.tag }}

            - ... other steps
```

## Prerequisites

### Runner Self-Hosted
You have to use the **self-hosted runner** to deploy your app in the specific environment.

### Kubernetes cluster URL and TOKEN
We suggest adding **cluster url** and **token** as repository secret.

### Deployment folder
In the root directory, create the **deploy** folder with the following structure:

```
- deploy
    - prod/
        - deployment.yml

    - qa/
        - deployment.yml

    - other-environments/
        - deployment.yml
```

### Deployment file with vars to replace in action
The action replaces the vars **${version}** and **${environment}** inside of *deployment.yml*

- **version:** Commonly used to identify the version of the Docker image.
- **environment:** Only if you deem it necessary. 