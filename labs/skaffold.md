# Lab: Skaffold

[Task Description](https://talks.timebertt.dev/platform-engineering/#/lab-skaffold)

## Create a Local Kubernetes Cluster

We can use [kind](https://kind.sigs.k8s.io/) to create a local Kubernetes cluster running in Docker containers.

```bash
brew install kind

# Store the kind kubeconfig in this file and
# configure kubectl/skaffold to use it
export KUBECONFIG=$PWD/kind-kubeconfig.yaml

# create a simple cluster with the default configuration
kind create cluster
```

## Create a Simple Web Application

We can create a simple web application with any programming language and framework. In this example, we will use Go with the built-in `net/http` package: [`web-app/main.go`](../web-app/main.go).

When running the application, a webserver is started on port 8888 that responds with "Hello, World!" to requests to the `/hello` endpoint.

```bash
$ cd web-app
 ~/workspaces/dhbw/platform-engineering-lab/web-app   main ✚  (kind-kind:default)
$ go run .
2025/12/03 15:44:23 Starting server on :8888

# in another termina
$ curl localhost:8888/hello
Hello, World!
```

## Containerize the Application

The simplest way to containerize Go applications is to use [ko](https://ko.build/), where we don't need to write a Dockerfile.
Instead, we can just run `ko build` to build and push the image to a container registry.
ko is integrated with Skaffold, so we can use it in our Skaffold configuration later.

## Add Kubernetes Manifests

The [`deploy/web-app/kustomization.yaml`](../deploy/web-app/kustomization.yaml) file contains a simple Kustomization including a Namespace, Deployment, and Service for our web application.

Note that the image reference in the deployment is just a placeholder (`web-app`).
Skaffold will replace it with the actual image tag during deployment.

## Skaffold Configuration

The skaffold configuration in [`skaffold.yaml`](../skaffold.yaml) specifies how to build and deploy our web application.
Additionally, it configures a port-forward from the local machine to the web application's service in the cluster, allowing us to access the application via `localhost:8888` – even though it's running inside the kind cluster.

## Run Skaffold

To build and deploy the application, we can use `skaffold run` (one-time build and deploy).

```bash
$ skaffold run
Generating tags...
 - web-app -> web-app:0d42a38-dirty
Checking cache...
 - web-app: Not found. Building
Starting build...
Found [kind-kind] context, using local docker daemon.
Building [web-app]...
...
Build [web-app] succeeded
Starting test...
Tags used in deployment:
 - web-app -> web-app:71c17b90afcd4cc238b210f8bf0b409d3573fc6ed9601b86e0199d60125a3bc9
Starting deploy...
Loading images into kind cluster nodes...
 - web-app:71c17b90afcd4cc238b210f8bf0b409d3573fc6ed9601b86e0199d60125a3bc9 -> Loaded
Images loaded in 940.39875ms
 - namespace/web-app created
 - service/web-app created
 - deployment.apps/web-app created
Waiting for deployments to stabilize...
 - web-app:deployment/web-app is ready.
Deployments stabilized in 8.075 seconds
You can also run [skaffold run --tail] to get the logs
```

After the deployment is complete, we can check the status of the deployment:

```bash
$ kubectl -n web-app get deploy -owide
NAME      READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                                                                     SELECTOR
web-app   1/1     1            1           12m   web-app      web-app:35230cbd899686cbd60f44b064807415ee6e2fb96753b3b147794f31c3b6f229   app=web-app
```

## Skaffold Dev Mode

With `skaffold dev`, we can start a continuous development mode that watches for changes in the source code, rebuilds the image, and redeploys the application automatically.
Additionally, Skaffold sets up port-forwarding based on the configuration in `skaffold.yaml` so that we can access the application via `localhost:8888`.

```bash
$ skaffold dev
...
Starting deploy...
Loading images into kind cluster nodes...
 - web-app:35230cbd899686cbd60f44b064807415ee6e2fb96753b3b147794f31c3b6f229 -> Found
Images loaded in 77.63075ms
Waiting for deployments to stabilize...
Deployments stabilized in 7.91175ms
Port forwarding service/web-app in namespace web-app, remote port 8888 -> http://127.0.0.1:8888
Watching for changes...
```

Now, if we make changes to the application code (e.g., modify the response message in `main.go`), Skaffold will automatically rebuild and redeploy the application.

```bash
$ curl localhost:8888/hello
Hello, World!

# edit the main.go file
# wait for skaffold to build the new image and redeploy the app

$ curl localhost:8888/hello
Hello, Platform Engineering!
```
