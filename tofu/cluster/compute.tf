data "openstack_compute_flavor_v2" "control_plane" {
  name = var.control_plane_node.flavor
}

data "openstack_compute_flavor_v2" "worker" {
  name = var.worker_nodes.flavor
}

data "openstack_images_image_v2" "image" {
  count       = var.image_id == "" ? 1 : 0
  name_regex  = "^${var.image_name}$"
  most_recent = true
}

resource "openstack_blockstorage_volume_v3" "node_boot" {
  for_each = local.nodes

  name        = "${each.value.name}-boot"
  description = "Boot volume for node ${each.value.name}"
  metadata    = local.common_metadata
  image_id    = var.image_id != "" ? var.image_id : data.openstack_images_image_v2.image[0].id
  size        = 10
}

# Separate data volume for k3s data storage (etcd data, certificates, container images, PersistentVolumes, etc.)
# This allows easier switching of node OS images without losing cluster data.
resource "openstack_blockstorage_volume_v3" "node_data" {
  for_each = local.nodes

  name        = "${each.value.name}-data"
  description = "Persistent data disk for node ${each.value.name}"
  metadata    = local.common_metadata
  size        = each.value.volume_size

  enable_online_resize = true
}

resource "openstack_compute_instance_v2" "node" {
  for_each = local.nodes

  name      = each.value.name
  tags      = local.common_tags_sanitized
  flavor_id = each.value.flavor_id
  key_pair  = openstack_compute_keypair_v2.keypair.name

  block_device {
    source_type      = "volume"
    uuid             = openstack_blockstorage_volume_v3.node_boot[each.key].id
    destination_type = "volume"
    boot_index       = 0
  }

  block_device {
    source_type      = "volume"
    uuid             = openstack_blockstorage_volume_v3.node_data[each.key].id
    destination_type = "volume"
    boot_index       = 1
  }

  network {
    port = openstack_networking_port_v2.node[each.key].id
  }

  user_data = templatefile("${path.module}/user_data.tftpl", {
    "role"                  = each.value.role
    "control_plane_ip"      = local.control_plane_ip
    "control_plane_address" = local.control_plane_address
    "node_ip"               = openstack_networking_port_v2.node[each.key].all_fixed_ips[0]
    "token"                 = random_password.k3s_token.result
    "ssh_user"              = var.ssh_username
    "k3s_data_device"       = "/dev/disk/by-id/virtio-${substr(openstack_blockstorage_volume_v3.node_data[each.key].id, 0, 20)}"
  })
}
