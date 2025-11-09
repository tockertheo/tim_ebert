# Lab: external-dns

[Task Description](https://talks.timebertt.dev/platform-engineering/#/lab-external-dns)

## Install external-dns

We manually create the secret in the `external-dns` namespace holding the service account key file downloaded from Moodle:

```bash
kubectl create namespace external-dns
kubectl -n external-dns create secret generic google-clouddns --from-file service-account.json=key.json
```

We install external-dns using the [official Helm Chart](https://kubernetes-sigs.github.io/external-dns/latest/charts/external-dns/) via a Flux `HelmRelease` in the [`clusters/dhbw/external-dns.yaml`](../clusters/dhbw/external-dns.yaml) file.
For this, we create a `HelmRepository` pointing to <https://kubernetes-sigs.github.io/external-dns>. 

We then create a `HelmRelease` that deploys the external-dns chart from this repository in the `external-dns` namespace.

In the values of the `HelmRelease`, we configure the `google` provider for Google Cloud DNS.
We set the `--google-project=timebertt-dhbw` flag to specify the Google Cloud project.
We also configure the `GOOGLE_APPLICATION_CREDENTIALS` environment variable to point to the service account key file mounted from the `google-clouddns` `Secret`.

```yaml
provider:
  name: google
extraArgs:
- --google-project=timebertt-dhbw

env:
- name: GOOGLE_APPLICATION_CREDENTIALS
  value: /etc/secrets/service-account/service-account.json
extraVolumeMounts:
- name: clouddns-credentials
  mountPath: /etc/secrets/service-account
  readOnly: true
extraVolumes:
- name: clouddns-credentials
  secret:
    secretName: google-clouddns
```

We enable the `Ingress` and `Service` sources to manage DNS records via both `Ingress` and `Service` resources:

```yaml
sources:
- ingress
- service
```

Lastly, we configure a unique owner ID corresponding to our cluster name to [prevent conflicts with other clusters](../README.md#dns-setup):

```yaml
registry: txt
txtOwnerId: <cluster-name> # e.g., student-abcd
```

After pushing the changes to GitHub, the results should look similar to the following:

```bash
$ kubectl -n external-dns get deploy,secret
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/external-dns   1/1     1            1           23s

NAME                     TYPE     DATA   AGE
secret/google-clouddns   Opaque   1      35s
```

See [this commit](https://github.com/timebertt/platform-engineering-lab/commit/78aff0312e28fd11f5c62380f9684c1091b5aee4) for the complete changes.

## Ingress Hostnames of the `podinfo` Application

The base `Ingress` resource of the `podinfo` application is configured in the [`deploy/podinfo/base/ingress.yaml`](../deploy/podinfo/base/ingress.yaml) file.
Note that this file does not specify the `host` field, as we want to set different hostnames for the `development` and `production` environments.
The `host` field is set in the respective overlays by a patch in the `kustomization.yaml` files.

See [this commit](https://github.com/timebertt/platform-engineering-lab/commit/a979958124916ebedd9f1ea5637e53c6ea2b188d) for the complete changes.

After committing the changes and pushing them to the GitHub repository, external-dns manages DNS records in Google Cloud DNS for the `Ingress` resources in both environments.

```bash
$ kubectl -n external-dns logs deploy/external-dns
# ...
time="2025-11-09T21:05:06Z" level=info msg="Change zone: dski23a-timebertt-dev batch #0"
time="2025-11-09T21:05:06Z" level=info msg="Add records: a-podinfo.timebertt.dski23a.timebertt.dev. TXT [\"heritage=external-dns,external-dns/owner=timebertt,external-dns/resource=ingress/podinfo-prod/podinfo\"] 300"
time="2025-11-09T21:05:06Z" level=info msg="Add records: podinfo.timebertt.dski23a.timebertt.dev. A [141.72.176.127 141.72.176.195 141.72.176.219] 300"
```

## Verify Ingress Access via Hostnames

We can connect to the `podinfo` application in both environments using `curl`.
This time, we can use the hostnames configured in the `Ingress` resources because external-dns has created the corresponding DNS records in Google Cloud DNS.

```bash
$ curl http://podinfo-dev.timebertt.dski23a.timebertt.dev
{
  "hostname": "podinfo-677d5f7896-drqbf",
  "version": "6.9.2",
  "revision": "e86405a8674ecab990d0a389824c7ebbd82973b5",
  "color": "#34577c",
  "logo": "https://raw.githubusercontent.com/stefanprodan/podinfo/gh-pages/cuddle_clap.gif",
  "message": "Hello, Platform Engineering!",
  "goos": "linux",
  "goarch": "amd64",
  "runtime": "go1.25.1",
  "num_goroutine": "8",
  "num_cpu": "8"
}

$ curl http://podinfo.timebertt.dski23a.timebertt.dev
{
  "hostname": "podinfo-ccc5dff5-clgvg",
  "version": "6.9.0",
  "revision": "fb3b01be30a3f353b221365cd3b4f9484a0885ea",
  "color": "#34577c",
  "logo": "https://raw.githubusercontent.com/stefanprodan/podinfo/gh-pages/cuddle_clap.gif",
  "message": "Hello, Platform Engineering!",
  "goos": "linux",
  "goarch": "amd64",
  "runtime": "go1.24.3",
  "num_goroutine": "8",
  "num_cpu": "8"
}
```
