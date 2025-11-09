# Lab: ingress-nginx

[Task Description](https://talks.timebertt.dev/platform-engineering/#/lab-ingress-nginx)

## Install ingress-nginx

We install ingress-nginx using the [official Helm Chart](https://kubernetes.github.io/ingress-nginx/deploy/) via a Flux `HelmRelease` in the [`clusters/dhbw/ingress-nginx.yaml`](../clusters/dhbw/ingress-nginx.yaml) file.
For this, we create a `HelmRepository` pointing to <https://kubernetes.github.io/ingress-nginx>. 

We then create a `HelmRelease` that deploys the ingress-nginx chart from this repository in the `ingress-nginx` namespace.

In the values of the `HelmRelease`, we configure the `nginx` `IngressClass` to be the [default `IngressClass`](https://kubernetes.io/docs/concepts/services-networking/ingress/#default-ingress-class) in the cluster.
With this, we don't need to specify the `ingressClassName` field in our `Ingress` resources explicitly.
Also, we enable the default backend, which serves a default 404 page for requests that don't match any configured `Ingress`.

```yaml
controller:
  ingressClassResource:
    default: true

defaultBackend:
  enabled: true
```

After pushing the changes to GitHub, the results should look similar to the following:

```bash
$ kubectl -n ingress-nginx get deploy,svc
NAME                                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/ingress-nginx-controller       1/1     1            1           18h
deployment.apps/ingress-nginx-defaultbackend   1/1     1            1           18h

NAME                                         TYPE           CLUSTER-IP      EXTERNAL-IP                                    PORT(S)                      AGE
service/ingress-nginx-controller             LoadBalancer   10.43.224.65    141.72.176.127,141.72.176.195,141.72.176.219   80:30740/TCP,443:32242/TCP   18h
service/ingress-nginx-controller-admission   ClusterIP      10.43.250.110   <none>                                         443/TCP                      18h
service/ingress-nginx-defaultbackend         ClusterIP      10.43.114.216   <none>                                         80/TCP                       18h

$ kubectl get ingressclass
NAME    CONTROLLER             PARAMETERS   AGE
nginx   k8s.io/ingress-nginx   <none>       18h
```

See [this commit](https://github.com/timebertt/platform-engineering-lab/commit/73f7b21bbc1eef81a83238d22995954d3a47fd7a) for the complete changes.

## Add Ingress to the `podinfo` Application

We add an `Ingress` resource to the `base` configuration of the `podinfo` application in the [`deploy/podinfo/base/ingress.yaml`](../deploy/podinfo/base/ingress.yaml) file.
Note that this file does not specify the `host` field, as we want to set different hostnames for the `development` and `production` environments.
The `host` field are set in the respective overlays by a patch in the `kustomization.yaml` files.

See [this commit](https://github.com/timebertt/platform-engineering-lab/commit/a979958124916ebedd9f1ea5637e53c6ea2b188d) for the complete changes.

After committing the changes and pushing them to the GitHub repository, Flux deploys the added `Ingress` resources in both environments.
Both `Ingress` objects should be ready and have an external address assigned.

```bash
$ kubectl get ing -A
NAMESPACE      NAME      CLASS   HOSTS                                         ADDRESS                                        PORTS   AGE
podinfo-dev    podinfo   nginx   podinfo-dev.timebertt.dski23a.timebertt.dev   141.72.176.127,141.72.176.195,141.72.176.219   80      89s
podinfo-prod   podinfo   nginx   podinfo.timebertt.dski23a.timebertt.dev       141.72.176.127,141.72.176.195,141.72.176.219   80      86s
```

## Verify Ingress Access

We can connect to the `podinfo` application in both environments using `curl`.
As long as we don't configure public DNS records for these hostnames, we need to connect to one of the external IP addresses directly and set the `Host` header to the requested hostname.
If we omit the `Host` header, we get the default backend's 404 page.

```bash
$ curl -H "Host: podinfo-dev.timebertt.dski23a.timebertt.dev" 141.72.176.127
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

$ curl -H "Host: podinfo.timebertt.dski23a.timebertt.dev" 141.72.176.127
{
  "hostname": "podinfo-ccc5dff5-zdvh9",
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

$ curl 141.72.176.127
default backend - 404
```
