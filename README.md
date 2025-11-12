# Platform Engineering Lab

This repository contains resources and code for the [Platform Engineering course](https://github.com/timebertt/talk-platform-engineering) at DHBW Mannheim.

## Lab Exercises

The course includes practical lab exercises covering various topics related to Kubernetes and cloud native tooling.
The exercises are designed to provide hands-on experience with the concepts and tools discussed in the lectures.

The tasks are introduced in the respective slides section (e.g., [Lab: Kustomize](https://talks.timebertt.dev/platform-engineering/#/lab-kustomize)).
Students are expected to complete the exercises using their individual Kubernetes clusters provided for the course.
The [labs directory](labs) contains solutions and explanations for each exercise:

- [Kustomize](labs/kustomize.md)
- [Helm](labs/helm.md)
- [Flux](labs/flux.md)
- [ingress-nginx](labs/ingress-nginx.md)
- [external-dns](labs/external-dns.md)
- [cert-manager](labs/cert-manager.md)
- [renovate](labs/renovate.md)

## Prerequisites

As a student, you should have the following knowledge and skills for this course:

- Familiarity with the command line and basic terminal commands
- Understanding of running and building containers with Docker
- Understanding of Kubernetes core concepts (e.g., pods, services, deployments)
- Interacting with Kubernetes clusters using `kubectl`

To prepare for the practical exercises in this course, ensure you have the following set up:

- Access to the DHBW network (e.g., via VPN)
- A local command line terminal (Linux, macOS, or Windows with WSL)
- A Code editor (e.g., [Visual Studio Code](https://code.visualstudio.com/))
- [Docker Desktop](https://docs.docker.com/get-docker/) (or comparable alternatives)
  - optional: [kind](https://kind.sigs.k8s.io/) for running local Kubernetes clusters
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) installed
  - optional: [k9s](https://k9scli.io/) installed for easier cluster navigation
- GitHub account (for creating individual repositories for exercises)
- Git installed and [authenticated with your GitHub account](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/about-authentication-to-github#authenticating-with-the-command-line)
  - optional: visual Git client (e.g., GitHub Desktop, Sourcetree)
- optional: SSH client (e.g., OpenSSH, PuTTY)

## Cluster Setup

Each student receives an individual Kubernetes cluster for practical exercises.
The credentials will be shared via one-time links at the beginning of the course.

The clusters are not set up for production use but provide a hands-on environment to gain practical experience with Kubernetes and the cloud native toolkit.
They are provisioned using the [OpenTofu](https://opentofu.org/) configuration in this repository (see the [cluster module](tofu/cluster/)) as follows:

- **Kubernetes Distribution:** [k3s](https://k3s.io/) (lightweight Kubernetes, simple to set up)
- **Cloud Platform:** Deployed on the [DHBW Cloud](https://dhbw.cloud/), a private OpenStack-based environment
- **Cluster Topology:**
  - 1 control plane node (k3s server)
    - runs cluster management components (e.g., API server, controller manager, scheduler)
    - excluded from scheduling workloads by default
    - excluded from handling LoadBalancer traffic
  - 3 worker nodes (k3s agent)
    - available for scheduling workloads
    - handle LoadBalancer traffic
- **Networking:**
  - Each node receives an external IP address
  - The control plane node exposes the Kubernetes API server via its external IP address
  - Each node can be accessed via SSH on its external IP address (port 22) using the cluster-specific private key (use the image's default user, e.g., `ubuntu` for Ubuntu)
  - Access to the cluster, nodes, and workload is only possible within the DHBW network (e.g., via VPN)
- **Load Balancers:**
  - [Services of type `LoadBalancer`](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer) are implemented using the built-in [k3s `servicelb` controller](https://docs.k3s.io/networking/networking-services#service-load-balancer)
  - It does not provision external cloud load balancers but runs a simple [iptables-based proxy](https://github.com/k3s-io/klipper-lb) on each worker node to forward traffic to the appropriate service
  - See limitations below
- **Persistent Volumes:**
  - `PersistentVolumes` are provisioned by the [local-path-provisioner](https://docs.k3s.io/storage#setting-up-the-local-storage-provider)
  - All persistent data is stored on a single data disk attached to each node
  - No external OpenStack block storage is provisioned individually per `PersistentVolumes`
  - See limitations below
- **Cluster Access:**
  - Students receive a `kubeconfig.yaml` file for accessing their cluster
  - Students also receive the SSH key for accessing the nodes of their cluster

### Limitations

- no high availability for control plane node
- static cluster bootstrapping configuration, i.e., no cluster autoscaling or automatic node management
- Services of type `LoadBalancer` must use distinct ports, e.g., only one LoadBalancer for port 443 is possible
- Ports allowed for LoadBalancers: 80, 443, 12000-12999 (configured in [security group rules](tofu/cluster/network.tf))
- `PersistentVolumes` are local to each node and cannot be shared or moved across nodes, i.e., pods using an existing `PersistentVolumes` cannot be rescheduled to other nodes

## DNS Setup

Until [dyndns.dhbw.cloud](https://dyndns.dhbw.cloud) is fully functional, we use a shared public zone (`dski23a.timebertt.dev.`) managed in Google Cloud DNS (zone name `dski23a-timebertt-dev`, project `timebertt-dhbw`).
All students can create records in this zone via the provided shared service account key.
Don't leak the key or commit it to Git!

To prevent conflicts between different clusters, each student must use a unique subdomain and external-dns owner ID corresponding to their cluster name (e.g., `student-abcd`):

- Each cluster uses a unique subdomain: `<cluster-name>.dski23a.timebertt.dev`
  - Example: `student-abcd.dski23a.timebertt.dev`
- Each cluster uses a unique external-dns owner ID: `<cluster-name>`
  - Example: `student-abcd`

## Contributions Welcome

If you spot any bugs or have suggestions for improvements of the course materials or cluster setup, feel free to open an issue or a pull request!
