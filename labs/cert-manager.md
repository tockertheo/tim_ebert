# Lab: cert-manager

[Task Description](https://talks.timebertt.dev/platform-engineering/#/lab-cert-manager)

## Install cert-manager

We manually create the secret in the `cert-manager` namespace holding the service account key file downloaded from [Moodle](https://moodle.dhbw-mannheim.de/course/section.php?id=103110):

```bash
kubectl create namespace cert-manager
kubectl -n cert-manager create secret generic google-clouddns --from-file service-account.json=key.json
```

We install cert-manager using the [official Helm Chart](https://cert-manager.io/docs/installation/helm/) via a Flux `HelmRelease` in the [`clusters/dhbw/cert-manager.yaml`](../clusters/dhbw/cert-manager.yaml) file.
For this, we create a `HelmRepository` of type `oci` pointing to `oci://quay.io/jetstack/charts`.

We then create a `HelmRelease` that deploys the cert-manager chart from this repository in the `cert-manager` namespace.

In the values of the `HelmRelease`, we enable the installation of the cert-manager CRDs, which are required for cert-manager to function but are not included by default in the Helm chart installation:

```yaml
crds:
  enabled: true
```

## Configure Issuers

Now, that we have cert-manager installed on the cluster, we need to configure how it should issue TLS certificates for our applications.
In this lab, we request certificates from [Let's Encrypt](https://letsencrypt.org/docs/) using the ACME protocol.

For this, we use the [DNS01 challenge](https://cert-manager.io/docs/configuration/acme/dns01/) to prove domain ownership by creating DNS records in Google Cloud DNS.
This works well for our lab environment, even if the applications are not accessible on the public internet – and therefore not accessible by Let's Encrypt.
Public access would be required for the HTTP01 challenge.
For DNS01 challenges, however, we only need to create DNS records in a publicly resolvable DNS zone.

We create `ClusterIssuer` resources in the [`deploy/cert-manager/cluster-issuers.yaml`](../deploy/cert-manager/cluster-issuers.yaml) file – one for the Let's Encrypt staging environment and one for the regular environment.
The [staging environment](https://letsencrypt.org/docs/staging-environment/) is useful for testing and development, as it has higher rate limits.
In comparison to the regular environment, it does not issue trusted certificates, though.

For using the ACME protocol with Let's Encrypt, we need to provide an email address for registration.
We provide cert-manager with a reference to the secret where it should store the generated private key for the ACME account.
The `ClusterIssuer` resource is cluster-scoped (it doesn't belong to a specific namespace), meaning that the secret will be created in the `cert-manager` namespace.

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    email: timebertt@gmail.com
    privateKeySecretRef:
      name: letsencrypt
    server: https://acme-v02.api.letsencrypt.org/directory
```

Apart from configuring the ACME server and account details, we also need to specify the [DNS01 solver configuration for Google Cloud DNS](https://cert-manager.io/docs/configuration/acme/dns01/google/).
This includes the Google Cloud project ID and a reference to the secret containing the service account key we created earlier.

```yaml
spec:
  acme:
    solvers:
    - dns01:
        cloudDNS:
          project: timebertt-dhbw
          serviceAccountSecretRef:
            name: google-clouddns
            key: service-account.json
```

We deploy the `ClusterIssuer` resources using a dedicated Flux `Kustomization` in the [`clusters/dhbw/cert-manager.yaml`](../clusters/dhbw/cert-manager.yaml) file.
Note that the `Kustomization` depends on the cert-manager `HelmRelease`, because the `ClusterIssuer` resources require the cert-manager CRDs to be present in the cluster.
In other words, CustomResourceDefinitions and corresponding custom resources cannot be placed in the same `Kustomization` and need to be applied separately.

After pushing the changes to GitHub, the results should look similar to the following:

```bash
$ kubectl -n cert-manager get deploy,secret,clusterissuer
NAME                                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/cert-manager              1/1     1            1           2m8s
deployment.apps/cert-manager-cainjector   1/1     1            1           2m8s
deployment.apps/cert-manager-webhook      1/1     1            1           2m8s

NAME                             TYPE     DATA   AGE
secret/cert-manager-webhook-ca   Opaque   3      2m7s
secret/google-clouddns           Opaque   1      20m
secret/letsencrypt               Opaque   1      4s
secret/letsencrypt-staging       Opaque   1      4s

NAME                                                READY   AGE
clusterissuer.cert-manager.io/letsencrypt           True    4s
clusterissuer.cert-manager.io/letsencrypt-staging   True    4s
```

See [this commit](https://github.com/timebertt/platform-engineering-lab/commit/00e4b86ab4524e60512f4434e8e50fb5a600cf2b) for the complete changes.

## TLS Certificates for the `podinfo` Application

The base `Ingress` resource of the `podinfo` application is configured in the [`deploy/podinfo/base/ingress.yaml`](../deploy/podinfo/base/ingress.yaml) file.
Here, we add the cert-manager annotation for specifying that it should manage TLS certificates for this `Ingress` resource using the `letsencrypt` `ClusterIssuer`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: podinfo
  annotations:
    # set this to letsencrypt-staging for testing purposes
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  # ...
  tls:
  - secretName: podinfo-tls
```

Note that this file does not specify the `host` and `tls[].hosts` fields, as we want to set different hostnames for the `development` and `production` environments.
We only specify the `tls[].secretName` field, which tells cert-manager the name of the secret where it should store the issued TLS certificate for this `Ingress` resource.
This is also the secret name that the `ingress-nginx` controller will fetch the TLS certificate from when serving HTTPS traffic.

The `host` and `tls[].hosts` fields are set in the respective overlays by a patch in the `kustomization.yaml` files, e.g.:

```yaml
patches:
- target:
    kind: Ingress
    name: podinfo
  patch: |
    - op: add
      path: /spec/rules/0/host
      value: &host podinfo.<cluster-name>.dski23a.timebertt.devtimebertt.dev
    - op: add
      path: /spec/tls/0/hosts
      value:
      - *host
```

We use a YAML anchor (`&host`) and alias (`*host`) to avoid repeating the hostname in both places ([ref](https://helm.sh/docs/chart_template_guide/yaml_techniques/#yaml-anchors)).
With this, both `Ingress` resources get the correct hostnames and TLS configuration for their respective environments.
For the `development` environment, this results in the following `Ingress` configuration:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: podinfo
  namespace: podinfo-dev
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  rules:
  - host: podinfo-dev.<cluster-name>.dski23a.timebertt.dev
    http:
      paths:
      - backend:
          service:
            name: podinfo
            port:
              name: http
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - podinfo-dev.<cluster-name>.dski23a.timebertt.dev
    secretName: podinfo-tls
```

See [this commit](https://github.com/timebertt/platform-engineering-lab/commit/b067abbb41755fe310793d07a24430ca88204c27) for the complete changes.

After committing the changes and pushing them to the GitHub repository, cert-manager will request TLS certificates for the `Ingress` resources in both environments from Let's Encrypt and store them in the specified secrets.
For example, the following output shows the resources in the `podinfo-dev` namespace after cert-manager has successfully issued a TLS certificate:

```bash
$ kubectl -n podinfo-dev get ing,secret,cert,certificaterequest,order,challenge
NAME                                CLASS   HOSTS                                         ADDRESS                                        PORTS     AGE
ingress.networking.k8s.io/podinfo   nginx   podinfo-dev.timebertt.dski23a.timebertt.dev   141.72.176.127,141.72.176.195,141.72.176.219   80, 443   44h

NAME                 TYPE                DATA   AGE
secret/podinfo-tls   kubernetes.io/tls   2      32s

NAME                                      READY   SECRET        AGE
certificate.cert-manager.io/podinfo-tls   True    podinfo-tls   2m11s

NAME                                               APPROVED   DENIED   READY   ISSUER        REQUESTER                                         AGE
certificaterequest.cert-manager.io/podinfo-tls-1   True                True    letsencrypt   system:serviceaccount:cert-manager:cert-manager   98s

NAME                                                STATE   AGE
order.acme.cert-manager.io/podinfo-tls-1-55673383   valid   98s
```

## Verify Ingress Access with TLS

Now that cert-manager has issued TLS certificates for the `podinfo` application in both environments, we can access them securely via HTTPS through the respective `Ingress` resources.
I.e., when accessing the application with `curl`, we should see that the connection is encrypted using a trusted TLS certificate issued by Let's Encrypt.

```bash
$ curl -v https://podinfo-dev.timebertt.dski23a.timebertt.dev
* Host podinfo-dev.timebertt.dski23a.timebertt.dev:443 was resolved.
* IPv6: (none)
* IPv4: 141.72.176.195, 141.72.176.219, 141.72.176.127
*   Trying 141.72.176.195:443...
* ALPN: curl offers h2,http/1.1
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (IN), TLS change cipher, Change cipher spec (1):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
* TLSv1.3 (IN), TLS handshake, Finished (20):
* TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
* TLSv1.3 (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384 / X25519MLKEM768 / RSASSA-PSS
* ALPN: server accepted h2
* Server certificate:
*  subject: CN=podinfo-dev.timebertt.dski23a.timebertt.dev
*  start date: Nov 10 05:47:31 2025 GMT
*  expire date: Feb  8 05:47:30 2026 GMT
*  subjectAltName: host "podinfo-dev.timebertt.dski23a.timebertt.dev" matched cert's "podinfo-dev.timebertt.dski23a.timebertt.dev"
*  issuer: C=US; O=Let's Encrypt; CN=R12
*  SSL certificate verify ok.
*   Certificate level 0: Public key type RSA (2048/112 Bits/secBits), signed using sha256WithRSAEncryption
*   Certificate level 1: Public key type RSA (2048/112 Bits/secBits), signed using sha256WithRSAEncryption
*   Certificate level 2: Public key type RSA (4096/152 Bits/secBits), signed using sha256WithRSAEncryption
* Connected to podinfo-dev.timebertt.dski23a.timebertt.dev (141.72.176.195) port 443
* using HTTP/2
* [HTTP/2] [1] OPENED stream for https://podinfo-dev.timebertt.dski23a.timebertt.dev/
* [HTTP/2] [1] [:method: GET]
* [HTTP/2] [1] [:scheme: https]
* [HTTP/2] [1] [:authority: podinfo-dev.timebertt.dski23a.timebertt.dev]
* [HTTP/2] [1] [:path: /]
* [HTTP/2] [1] [user-agent: curl/8.12.1]
* [HTTP/2] [1] [accept: */*]
> GET / HTTP/2
> Host: podinfo-dev.timebertt.dski23a.timebertt.dev
> User-Agent: curl/8.12.1
> Accept: */*
>
* Request completely sent off
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
< HTTP/2 200
< date: Mon, 10 Nov 2025 06:51:42 GMT
< content-type: application/json; charset=utf-8
< content-length: 391
< x-content-type-options: nosniff
< strict-transport-security: max-age=31536000; includeSubDomains
<
{
  "hostname": "podinfo-677d5f7896-xxwxs",
  "version": "6.9.2",
  "revision": "e86405a8674ecab990d0a389824c7ebbd82973b5",
  "color": "#34577c",
  "logo": "https://raw.githubusercontent.com/stefanprodan/podinfo/gh-pages/cuddle_clap.gif",
  "message": "Hello, Platform Engineering!",
  "goos": "linux",
  "goarch": "amd64",
  "runtime": "go1.25.1",
  "num_goroutine": "9",
  "num_cpu": "8"
* Connection #0 to host podinfo-dev.timebertt.dski23a.timebertt.dev left intact
}
```

We should also see that `ingress-nginx` serves a redirect (308 Permanent Redirect) to the HTTPS URL when accessing the application via HTTP:

```bash
$ curl -v http://podinfo-dev.timebertt.dski23a.timebertt.dev
* Host podinfo-dev.timebertt.dski23a.timebertt.dev:80 was resolved.
* IPv6: (none)
* IPv4: 141.72.176.127, 141.72.176.195, 141.72.176.219
*   Trying 141.72.176.127:80...
* Connected to podinfo-dev.timebertt.dski23a.timebertt.dev (141.72.176.127) port 80
* using HTTP/1.x
> GET / HTTP/1.1
> Host: podinfo-dev.timebertt.dski23a.timebertt.dev
> User-Agent: curl/8.12.1
> Accept: */*
>
* Request completely sent off
< HTTP/1.1 308 Permanent Redirect
< Date: Mon, 10 Nov 2025 06:53:22 GMT
< Content-Type: text/html
< Content-Length: 164
< Connection: keep-alive
< Location: https://podinfo-dev.timebertt.dski23a.timebertt.dev
<
<html>
<head><title>308 Permanent Redirect</title></head>
<body>
<center><h1>308 Permanent Redirect</h1></center>
<hr><center>nginx</center>
</body>
</html>
* Connection #0 to host podinfo-dev.timebertt.dski23a.timebertt.dev left intact
```

With this, we can open the `podinfo` application in both environments securely via HTTPS in the browser, without seeing any security warnings:
- `development`: <https://podinfo-dev.timebertt.dski23a.timebertt.dev>
- `production`: <https://podinfo.timebertt.dski23a.timebertt.dev>
