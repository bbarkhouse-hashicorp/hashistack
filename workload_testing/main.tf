terraform {
  required_providers {

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
    consul = {
      source = "hashicorp/consul"
      version = "2.21.0"
    }

  }
}
provider "vault" {
  address = data.terraform_remote_state.hcp_clusters.outputs.vault_public_endpoint
  token = data.terraform_remote_state.hcp_clusters.outputs.vault_root_token
  namespace = "admin"
}
provider "nomad" {
  address = data.terraform_remote_state.nomad_cluster.outputs.nomad_public_endpoint
  secret_id = data.vault_kv_secret_v2.bootstrap.data["SecretID"]
}
provider "consul" {
address = data.terraform_remote_state.hcp_clusters.consul_public_endpoint
token = data.terraform_remote_state.hcp_clusters.consul_root_token
}

variable "service_name" {
    type = string
    default = "demo-mongodb"
  
}

resource "nomad_job" "mongodb" {
    jobspec = <<EOT
    job "demo-mongodb" {
    datacenters = ["dc1"]
    node_pool = "arm"
    type = "service"

    group "mongodb" {
        network {
            mode = "bridge"
            port "http" {
                static = 27017
                to     = 27017
            }
        }

        service {
            name = "${var.service_name}"
            port = "27017"
            address = "${attr.unique.platform.aws.public-ipv4}"
        } 

        task "mongodb" {
            driver = "docker"

            config {
                image = "mongo:5"
            }
            env {
                # This will immedietely be rotated be Vault
                MONGO_INITDB_ROOT_USERNAME = "admin"
                MONGO_INITDB_ROOT_PASSWORD = "password"
            }
        }
    }
}
EOT  
}

data "consul_service" "mongodb" {
    name = "${var.service_name}"
}

resource "vault_database_secrets_mount" "db" {
    path = "db"
    mongodb {
        name = "mongodb"
        connection_url = "mongodb://{{username}}:{{password}}@${data.consul_service.mongodb.name}.service.consul:${data.consul_service.mongodb.port}"
    }
    depends_on = [ nomad_job.mongodb ]
}

