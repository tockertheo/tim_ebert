# Lab: Flux

[Task Description](https://talks.timebertt.dev/platform-engineering/#/lab-flux)

## Bootstrap Flux

To get started, install the [Flux CLI](https://fluxcd.io/flux/get-started/#install-the-flux-cli).
For setting up the GitHub repository and pushing the initial manifests, you need a GitHub account and a [personal access token](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line) with appropriate permissions.
Alternatively, you can use the [GitHub CLI](https://cli.github.com/) to authenticate using `gh auth login` and `gh auth token`.

```bash
# Install the Flux CLI
brew install fluxcd/tap/flux

# Authenticate with GitHub (using the GitHub CLI or a personal access token)
export GITHUB_USER=timebertt
export GITHUB_TOKEN=$(gh auth token)

# Check prerequisites
flux check --pre

# Create your GitHub repository and bootstrap Flux on the cluster
$ flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=platform-engineering-lab \
  --branch=main \
  --path=./clusters/dhbw \
  --personal
► connecting to github.com
► cloning branch "main" from Git repository "https://github.com/timebertt/platform-engineering-lab.git"
✔ cloned repository
► generating component manifests
✔ generated component manifests
✔ committed component manifests to "main" ("79f9d24ffdc58a9ef122a8329b192cc059c90bf8")
► pushing component manifests to "https://github.com/timebertt/platform-engineering-lab.git"
► installing components in "flux-system" namespace
✔ installed components
✔ reconciled components
► determining if source secret "flux-system/flux-system" exists
► generating source secret
✔ public key: ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBMOggbguYFg2P4fhS+VAI97uu81/U5EhN412JkehHyOPJ7EQXL7oP+zP3YpDCt+E3a1lp8KcNesEzo2ilTqA23fawcAo4LFVRUx/TDpFKas/ExClr0KfI84N76uXQkECMw==
✔ configured deploy key "flux-system-main-flux-system-./clusters/dhbw" for "https://github.com/timebertt/platform-engineering-lab"
► applying source secret "flux-system/flux-system"
✔ reconciled source secret
► generating sync manifests
✔ generated sync manifests
✔ committed sync manifests to "main" ("4b2e61a067c7bb26f39907c77d8f124e6d75c2c7")
► pushing sync manifests to "https://github.com/timebertt/platform-engineering-lab.git"
► applying sync manifests
✔ reconciled sync configuration
◎ waiting for GitRepository "flux-system/flux-system" to be reconciled
✔ GitRepository reconciled successfully
◎ waiting for Kustomization "flux-system/flux-system" to be reconciled
✔ Kustomization reconciled successfully
► confirming components are healthy
✔ helm-controller: deployment ready
✔ kustomize-controller: deployment ready
✔ notification-controller: deployment ready
✔ source-controller: deployment ready
✔ all components are healthy
```

First, The `flux bootstrap github` command creates a new GitHub repository if it does not exist already.

Then, it generates the Flux component manifests, similar to the `install.yaml` manifest in [Flux releases](https://github.com/fluxcd/flux2/releases).
The manifest is pushed to the GitHub repository under the specified path within the `flux-system` directory: [`clusters/dhbw/flux-system/gotk-components.yaml`](../clusters/dhbw/flux-system/gotk-components.yaml) (see [commit](https://github.com/timebertt/platform-engineering-lab/commit/79f9d24ffdc58a9ef122a8329b192cc059c90bf8)).
This manifest file includes the Flux Custom Resource Definitions (CRDs) and the controller deployments.
The file is applied to the cluster to install Flux, i.e., using the equivalent `kubectl apply --server-side -f gotk-components.yaml`.
This command can also be used to reinstall Flux in case it was removed from the cluster and the manifests are still present in the GitHub repository.

Next, the command generates a source secret for accessing the GitHub repository and configures a deploy key in the repository settings.
This is an SSH key pair that allows Flux to pull the manifests from GitHub securely – including from private repositories.
The source secret is applied to the cluster (named `flux-system` in the `flux-system` namespace).
This secret will be referenced by the `GitRepository` resource to authenticate with the GitHub repository.
Note that authentication would not be required for this particular repository, as it is public.
If lost, a new source secret can be generated using `flux create source git` with the same parameters.

Finally, the command generates sync manifests for bootstrapping the initial `GitRepository` and `Kustomization` resources (both called `flux-system` and located in the `flux-system` namespace).
These manifests are committed and pushed to the GitHub repository: [`clusters/dhbw/flux-system/gotk-sync.yaml`](../clusters/dhbw/flux-system/gotk-sync.yaml) (see [commit](https://github.com/timebertt/platform-engineering-lab/commit/4b2e61a067c7bb26f39907c77d8f124e6d75c2c7)).
The manifests are applied to the cluster to configure Flux to start reconciling the resources from the GitHub repository.
For re-configuring a broken Flux installation, you can simply apply the `gotk-sync.yaml` manifest again.

Note that the initial `flux-system` `Kustomization` resource points to the `./clusters/dhbw` path in the repository, which includes the `flux-system` directory where the Flux manifests are located.
This means that Flux will apply its own manifests, enabling us to manage and upgrade Flux declaratively via GitOps as well.

Finally, the command waits for all components to become healthy, indicating that Flux has been successfully bootstrapped on the cluster.
The installation can also be verified using `flux check`.

The results should look something like this:

```bash
$ kubectl -n flux-system get po,gitrepo,ks
NAME                                           READY   STATUS    RESTARTS   AGE
pod/helm-controller-8474d9ccc5-5bbph           1/1     Running   0          33m
pod/kustomize-controller-5596c6b476-tg2nl      1/1     Running   0          33m
pod/notification-controller-75fc474646-p8256   1/1     Running   0          33m
pod/source-controller-7b565f499f-29fgv         1/1     Running   0          33m

NAME                                                 URL                                                       AGE   READY   STATUS
gitrepository.source.toolkit.fluxcd.io/flux-system   ssh://git@github.com/timebertt/platform-engineering-lab   33m   True    stored artifact for revision 'main@sha1:4b2e61a067c7bb26f39907c77d8f124e6d75c2c7'

NAME                                                    AGE   READY   STATUS
kustomization.kustomize.toolkit.fluxcd.io/flux-system   33m   True    Applied revision: main@sha1:4b2e61a067c7bb26f39907c77d8f124e6d75c2c7

$ flux tree kustomization flux-system
Kustomization/flux-system/flux-system
├── CustomResourceDefinition/alerts.notification.toolkit.fluxcd.io
├── CustomResourceDefinition/buckets.source.toolkit.fluxcd.io
├── CustomResourceDefinition/externalartifacts.source.toolkit.fluxcd.io
├── CustomResourceDefinition/gitrepositories.source.toolkit.fluxcd.io
├── CustomResourceDefinition/helmcharts.source.toolkit.fluxcd.io
├── CustomResourceDefinition/helmreleases.helm.toolkit.fluxcd.io
├── CustomResourceDefinition/helmrepositories.source.toolkit.fluxcd.io
├── CustomResourceDefinition/kustomizations.kustomize.toolkit.fluxcd.io
├── CustomResourceDefinition/ocirepositories.source.toolkit.fluxcd.io
├── CustomResourceDefinition/providers.notification.toolkit.fluxcd.io
├── CustomResourceDefinition/receivers.notification.toolkit.fluxcd.io
├── Namespace/flux-system
├── ClusterRole/crd-controller-flux-system
├── ClusterRole/flux-edit-flux-system
├── ClusterRole/flux-view-flux-system
├── ClusterRoleBinding/cluster-reconciler-flux-system
├── ClusterRoleBinding/crd-controller-flux-system
├── ResourceQuota/flux-system/critical-pods-flux-system
├── ServiceAccount/flux-system/helm-controller
├── ServiceAccount/flux-system/kustomize-controller
├── ServiceAccount/flux-system/notification-controller
├── ServiceAccount/flux-system/source-controller
├── Service/flux-system/notification-controller
├── Service/flux-system/source-controller
├── Service/flux-system/webhook-receiver
├── Deployment/flux-system/helm-controller
├── Deployment/flux-system/kustomize-controller
├── Deployment/flux-system/notification-controller
├── Deployment/flux-system/source-controller
├── NetworkPolicy/flux-system/allow-egress
├── NetworkPolicy/flux-system/allow-scraping
├── NetworkPolicy/flux-system/allow-webhooks
└── GitRepository/flux-system/flux-system
```

## Deploy the `podinfo` Application

Generate `Kustomization` manifests for the `podinfo` application in both `development` and `production` environments using the Flux CLI.
The Kustomizations should apply the manifests from the `./deploy/podinfo/overlays/*` directories of this repository (called `flux-system` in the cluster).
The generated manifests are pushed to the [`./clusters/dhbw`](../clusters/dhbw) directory for Flux to pick them up (see [commit](https://github.com/timebertt/platform-engineering-lab/commit/7453df75ed0f38e4caa8af574fa2d711a3314da2)).

```bash
flux create kustomization podinfo-dev \
  --source=flux-system \
  --path="./deploy/podinfo/overlays/development" \
  --prune=true \
  --wait=true \
  --interval=30m \
  --retry-interval=2m \
  --health-check-timeout=3m \
  --export > ./clusters/dhbw/podinfo-dev.yaml

flux create kustomization podinfo-prod \
  --source=flux-system \
  --path="./deploy/podinfo/overlays/production" \
  --prune=true \
  --wait=true \
  --interval=30m \
  --retry-interval=2m \
  --health-check-timeout=3m \
  --export > ./clusters/dhbw/podinfo-prod.yaml

git add clusters/dhbw/podinfo-*.yaml
git commit -m "Add podinfo Kustomizations for Flux"
git push origin main
```

After pushing the changes to GitHub, Flux will automatically detect the new Kustomizations and deploy the `podinfo` application to the cluster in both environments.

```bash
$ kubectl -n flux-system get ks
NAME           AGE   READY   STATUS
flux-system    42m   True    Applied revision: main@sha1:7453df75ed0f38e4caa8af574fa2d711a3314da2
podinfo-dev    15s   True    Applied revision: main@sha1:7453df75ed0f38e4caa8af574fa2d711a3314da2
podinfo-prod   15s   True    Applied revision: main@sha1:7453df75ed0f38e4caa8af574fa2d711a3314da2

$ flux tree kustomization flux-system
Kustomization/flux-system/flux-system
├── ...
├── Kustomization/flux-system/podinfo-dev
│   ├── Namespace/podinfo-dev
│   ├── ConfigMap/podinfo-dev/podinfo-config-6k4m67h8g9
│   ├── Service/podinfo-dev/podinfo
│   ├── Deployment/podinfo-dev/podinfo
│   └── HorizontalPodAutoscaler/podinfo-dev/podinfo
├── Kustomization/flux-system/podinfo-prod
│   ├── Namespace/podinfo-prod
│   ├── ConfigMap/podinfo-prod/podinfo-config-6k4m67h8g9
│   ├── Service/podinfo-prod/podinfo
│   ├── Deployment/podinfo-prod/podinfo
│   └── HorizontalPodAutoscaler/podinfo-prod/podinfo
├── ...
```
