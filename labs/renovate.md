# Lab: Renovate

[Task Description](https://talks.timebertt.dev/platform-engineering/#/lab-renovate)

## Install the Renovate GitHub App

Follow the [Renovate documentation](https://docs.renovatebot.com/getting-started/installing-onboarding/) and install the Renovate GitHub App on your repository.

Renovate opens a pull request adding a simple `renovate.json` config file: [onboarding pull request for this repository](https://github.com/timebertt/platform-engineering-lab/pull/1).
Review and merge the configuration PR to start receiving dependency update PRs.

After merging the configuration PR, Renovate opens a "Dependency Dashboard" issue to track updates: [Dependency Dashboard for this repository](https://github.com/timebertt/platform-engineering-lab/issues/4).
It even created the first dependency update PR: [example Renovate PR](https://github.com/timebertt/platform-engineering-lab/pull/2).

To allow Renovate to automerge update PRs, we need to enable the "Allow auto-merge" option in the repository settings under "Pull Requests" (see [docs](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/automatically-merging-a-pull-request)).

## Customize the Renovate Configuration

First, we edit the `renovate.json` configuration file to configure the wanted managers to find the relevant YAML files:

```json5
{
  "kubernetes": {
    // Find Kubernetes manifests in all YAML files of the repository
    "managerFilePatterns": ["/\\.yaml$/"]
  },
  "flux": {
    // All flux manifests are located in the clusters/ directory
    "managerFilePatterns": ["/^clusters/.*\\.yaml$/"]
  },
  "helm-values": {
    // Detect helm values in all YAML files of the repository
    "managerFilePatterns": ["/\\.yaml$/"]
  }
}
```

Next, we want to configure Renovate to automerge all patch updates.
For this, we define a package rule matching patch updates and enabling automerge for them.
Also, we need to set `ignoreTests` to `true` to skip the status checks in update PRs, as we do not have any tests configured in this repository.
Additionally, we can configure how Renovate should auto-merge the PRs.
In this config, we select the "squash" merging strategy, which combines commits of a PR into a single commit on the main branch.

```json5
{
  "packageRules": [
    {
      "description": "Automerge all patch updates",
      "matchUpdateTypes": ["patch"],
      "automerge": true
    }
  ],
  "ignoreTests": true,
  "automergeStrategy": "squash"
}
```

After pushing the changes to GitHub, we can observe Renovate creating update PRs for any outdated dependencies in the repository.
Also, the "Dependency Dashboard" issue is updated accordingly.
Furthermore, Renovate should now automatically merge the patch update PR for the `podinfo` image version in the `deploy/podinfo/overlays/production/kustomization.yaml` (see [pull request](https://github.com/timebertt/platform-engineering-lab/pull/2)).
