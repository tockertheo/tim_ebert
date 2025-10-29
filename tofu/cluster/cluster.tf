resource "random_pet" "cluster_name" {
  count = var.name == "" ? 1 : 0

  length = 2
}

locals {
  cluster_name  = var.name != "" ? var.name : random_pet.cluster_name[0].id
  resource_name = "cluster-${local.cluster_name}"
  common_metadata = {
    "module"                = "cluster"
    "kubernetes.io/cluster" = local.cluster_name
  }
  common_tags = [for k, v in local.common_metadata : "${k}=${v}"]
  # Some OpenStack resource tag values must not contain ',' or '/'.
  # Sanitize metadata keys by replacing '/' with '_'.
  common_tags_sanitized = [for k, v in local.common_metadata : "${replace(k, "/", "_")}=${v}"]

  nodes = merge(
    {
      "control-plane" = {
        role        = "control-plane"
        name        = "${local.resource_name}-control-plane"
        flavor_id   = data.openstack_compute_flavor_v2.control_plane.id
        volume_size = 20
      }
    },
    {
      for i in range(var.worker_nodes.count) :
      "worker-${i}" => {
        role        = "worker"
        name        = "${local.resource_name}-worker-${i}"
        flavor_id   = data.openstack_compute_flavor_v2.worker.id
        volume_size = 100
      }
    }
  )
}

resource "terraform_data" "fetch_kubeconfig" {
  triggers_replace = {
    instance_id = openstack_compute_instance_v2.node["control-plane"].id
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /home/${var.ssh_username}/kubeconfig.yaml ]; do echo 'Waiting for k3s installation to finish...' && sleep 10; done"
    ]

    connection {
      type        = "ssh"
      user        = var.ssh_username
      private_key = tls_private_key.ssh_key.private_key_openssh
      host        = local.control_plane_ip
    }
  }

  provisioner "local-exec" {
    command = <<-EOT
      scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -i ${local_sensitive_file.ssh_private_key.filename} \
          ${var.ssh_username}@${local.control_plane_ip}:/home/${var.ssh_username}/kubeconfig.yaml \
          ${local.kubeconfig_path}
    EOT
  }
}

resource "random_password" "k3s_token" {
  length  = 64
  special = false
}

locals {
  kubeconfig_path = "${path.root}/secrets/${local.cluster_name}/kubeconfig.yaml"
}

data "local_file" "kubeconfig" {
  filename = local.kubeconfig_path

  depends_on = [terraform_data.fetch_kubeconfig]
}

output "kubeconfig" {
  description = "Kubeconfig for external cluster access."
  value       = data.local_file.kubeconfig.content
  sensitive   = true
}
