data "openstack_networking_network_v2" "ext_network" {
  name = "DHBW"
}

resource "openstack_networking_port_v2" "node" {
  for_each = local.nodes

  name        = each.value.name
  description = "Port for node ${each.value.name}"
  tags        = local.common_tags

  network_id = data.openstack_networking_network_v2.ext_network.id
  security_group_ids = concat(
    [openstack_networking_secgroup_v2.cluster.id],
    each.value.role == "control-plane" ?
    [openstack_networking_secgroup_v2.control_plane.id] :
    [openstack_networking_secgroup_v2.worker.id]
  )
}

locals {
  control_plane_ip      = openstack_networking_port_v2.node["control-plane"].all_fixed_ips[0]
  control_plane_address = "https://${local.control_plane_ip}:6443"
}

output "control_plane_ip" {
  description = "Control plane IP address."
  value       = local.control_plane_ip
}

output "control_plane_address" {
  description = "Control plane address (URI)."
  value       = local.control_plane_address
}

resource "openstack_networking_secgroup_v2" "cluster" {
  name        = local.resource_name
  description = "Security group for all nodes of cluster ${local.cluster_name}"
  tags        = local.common_tags
}

resource "openstack_networking_secgroup_rule_v2" "cluster_ssh" {
  description       = "Allow SSH (port 22) from anywhere"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.cluster.id
}

resource "openstack_networking_secgroup_rule_v2" "cluster_icmp" {
  description       = "Allow ICMP from anywhere"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.cluster.id
}

resource "openstack_networking_secgroup_rule_v2" "cluster_self_ingress" {
  description       = "Allow all ingress from all nodes of cluster ${local.cluster_name}"
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.cluster.id
  remote_group_id   = openstack_networking_secgroup_v2.cluster.id
}

resource "openstack_networking_secgroup_v2" "control_plane" {
  name        = "${local.resource_name}-control-plane"
  description = "Security group for control plane node of cluster ${local.cluster_name}"
  tags        = local.common_tags
}

resource "openstack_networking_secgroup_rule_v2" "control_plane_kube_apiserver" {
  description       = "Allow kube-apiserver access from anywhere"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_secgroup_v2" "worker" {
  name        = "${local.resource_name}-worker"
  description = "Security group for worker nodes of cluster ${local.cluster_name}"
  tags        = local.common_tags
}

resource "openstack_networking_secgroup_rule_v2" "worker_http" {
  description       = "Allow HTTP access (LoadBalancers) from anywhere"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.worker.id
}

resource "openstack_networking_secgroup_rule_v2" "worker_https" {
  description       = "Allow HTTPS access (LoadBalancers) from anywhere"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.worker.id
}

resource "openstack_networking_secgroup_rule_v2" "worker_loadbalancers" {
  description       = "Allow access to ports 12000-12999 (LoadBalancers) from anywhere"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 12000
  port_range_max    = 12999
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.worker.id
}
