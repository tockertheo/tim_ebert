# Lab: Grafana

[Task Description](https://talks.timebertt.dev/platform-engineering/#/lab-grafana)

## Access Grafana

With the [previous labs](kube-prometheus-stack.md), we have installed the kube-prometheus-stack Helm chart, which includes Grafana.
It is already pre-configured with a Prometheus data source that connects to the Prometheus instance deployed in the `monitoring` namespace.
We configured an ingress resource to access Grafana.
Determine the URL to access the Grafana instance by checking the ingress resource in the `monitoring` namespace and open it in your web browser.

```bash
$ kubectl -n monitoring get ing
NAME                               CLASS   HOSTS                                             ADDRESS                                        PORTS     AGE
kube-prometheus-stack-grafana      nginx   grafana.<cluster-name>.dski23a.timebertt.dev      141.72.176.127,141.72.176.195,141.72.176.219   80, 443   8d
kube-prometheus-stack-prometheus   nginx   prometheus.<cluster-name>.dski23a.timebertt.dev   141.72.176.127,141.72.176.195,141.72.176.219   80, 443   8d
```

When accessing Grafana, we need to log in to view the dashboards and explore the metrics.
The helm chart generates a random password for the `admin` user and stores it in a Kubernetes `Secret` in the `monitoring` namespace.
We can retrieve the password using the following command:

```bash
$ kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode; echo
```

Copy the output of this command and use it to log in to Grafana with the username `admin`.

## The `podinfo` Dashboard

The dashboard created for this lab is exported to a json file in this repository: [`deploy/grafana/dashboards/podinfo.json`](../deploy/grafana/dashboards/podinfo.json).
It can be imported into a running Grafana instance to recreate the dashboard.
