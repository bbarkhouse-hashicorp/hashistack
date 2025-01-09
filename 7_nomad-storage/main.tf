terraform {
  required_providers {
    doormat = {
      source  = "doormat.hashicorp.services/hashicorp-security/doormat"
      version = "~> 0.0.6"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.8.0"
    }

    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.66.0"
    }

    vault = {
      source = "hashicorp/vault"
      version = "~> 3.18.0"
    }

    nomad = {
      source = "hashicorp/nomad"
      version = "2.0.0-beta.1"
    }
  }
}

provider "doormat" {}

provider "hcp" {}

data "doormat_aws_credentials" "creds" {
  provider = doormat
  role_arn = "arn:aws:iam::${var.aws_account_id}:role/tfc-doormat-role_7_nomad-storage"
}

provider "aws" {
  region     = var.region
  access_key = data.doormat_aws_credentials.creds.access_key
  secret_key = data.doormat_aws_credentials.creds.secret_key
  token      = data.doormat_aws_credentials.creds.token
}

provider "vault" {}

data "vault_kv_secret_v2" "bootstrap" {
  mount = data.terraform_remote_state.nomad_cluster.outputs.bootstrap_kv
  name  = "nomad_bootstrap/SecretID"
}

provider "nomad" {
  address = data.terraform_remote_state.nomad_cluster.outputs.nomad_public_endpoint
  secret_id = data.vault_kv_secret_v2.bootstrap.data["SecretID"]
}

data "terraform_remote_state" "nomad_cluster" {
  backend = "remote"

  config = {
    organization = var.tfc_organization
    workspaces = {
      name = "5_nomad-cluster"
    }
  }
}


data "aws_iam_role" "role" {
    name = "tfc-doormat-role_7_nomad-storage"
}

resource "aws_iam_role_policy" "mount_ebs_volumes" {
  name   = "mount-ebs-volumes"
  role   = data.aws_iam_role.role.id
  policy = data.aws_iam_policy_document.mount_ebs_volumes.json
}

data "aws_iam_policy_document" "mount_ebs_volumes" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
    ]
    resources = ["*"]
  }
}

resource "aws_ebs_volume" "nomad-us-east-1a" {
  availability_zone = "us-east-1a"
  size              = 40
}

resource "aws_ebs_volume" "nomad-us-east-1b" {
  availability_zone = "us-east-1b"
  size              = 40
}

resource "aws_ebs_volume" "nomad-us-east-1c" {
  availability_zone = "us-east-1c"
  size              = 40
}



resource "nomad_job" "ebs-controller" {
    jobspec = <<EOT
job "plugin-aws-ebs-controller" {
  datacenters = ["dc1"]
  node_pool = "all"

  group "controller" {
    task "plugin" {
      driver = "docker"

      config {
        image = "amazon/aws-ebs-csi-driver:v0.10.1"

        args = [
          "controller",
          "--endpoint=unix://csi/csi.sock",
          "--logtostderr",
          "--v=5",
        ]
      }

      csi_plugin {
        id        = "aws-ebs0"
        type      = "controller"
        mount_dir = "/csi"
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}
EOT
}

resource "nomad_job" "ebs-nodes" {
    jobspec = <<EOT
    job "plugin-aws-ebs-nodes" {
  datacenters = ["dc1"]
  node_pool = "all"

  # you can run node plugins as service jobs as well, but this ensures
  # that all nodes in the DC have a copy.
  type = "system"

  group "nodes" {
    task "plugin" {
      driver = "docker"

      config {
        image = "amazon/aws-ebs-csi-driver:v0.10.1"

        args = [
          "node",
          "--endpoint=unix://csi/csi.sock",
          "--logtostderr",
          "--v=5",
        ]

        # node plugins must run as privileged jobs because they
        # mount disks to the host
        privileged = true
      }

      csi_plugin {
        id        = "aws-ebs0"
        type      = "node"
        mount_dir = "/csi"
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}
EOT  
}

data "nomad_plugin" "ebs" {
    plugin_id = "aws-ebs0"
    wait_for_healthy = true
}

resource "nomad_csi_volume_registration" "nomad_volume-1a" {
  depends_on = [data.nomad_plugin.ebs]
  plugin_id = "aws-ebs0"
  volume_id = "nomad-us-east-1a"
  name = "nomad-us-east-1a"
  external_id = aws_ebs_volume.nomad-us-east-1a.id
  capability {
    access_mode = "single-node-writer"
    attachment_mode = "file-system"
  }
}

resource "nomad_csi_volume_registration" "nomad_volume-1b" {
  depends_on = [data.nomad_plugin.ebs]
  plugin_id = "aws-ebs0"
  volume_id = "nomad-us-east-1b"
  name = "nomad-us-east-1b"
  external_id = aws_ebs_volume.nomad-us-east-1b.id
  capability {
    access_mode = "single-node-writer"
    attachment_mode = "file-system"
  }
}

resource "nomad_csi_volume_registration" "nomad_volume-1c" {
  depends_on = [data.nomad_plugin.ebs]
  plugin_id = "aws-ebs0"
  volume_id = "nomad-us-east-1c"
  name = "nomad-us-east-1c"
  external_id = aws_ebs_volume.nomad-us-east-1c.id
  capability {
    access_mode = "single-node-writer"
    attachment_mode = "file-system"
  }
}

resource "nomad_job" "mysql" {
    depends_on = [ nomad_csi_volume_registration.nomad_volume-1a, nomad_csi_volume_registration.nomad_volume-1b, nomad_csi_volume_registration.nomad_volume-1c ]
    jobspec = <<EOT
job "mysql-server" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool = "x86"
  constraint {
    attribute = "${attr.platform.aws.placement.availability-zone}"
    value = "us-east-1b"
  }
  group "mysql-server" {
    count = 1

    volume "mysql" {
      type            = "csi"
      read_only       = false
      source          = "nomad-us-east-1b"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    network {
      port "db" {
        static = 3306
      }
    }

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    task "mysql-server" {
      driver = "docker"

      volume_mount {
        volume      = "mysql"
        destination = "/srv"
        read_only   = false
      }

      env {
        MYSQL_ROOT_PASSWORD = "password"
      }

      config {
        image = "hashicorp/mysql-portworx-demo:latest"
        args  = ["--datadir", "/srv/mysql"]
        ports = ["db"]
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      service {
        name = "mysql-server"
        port = "db"

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
EOT
}