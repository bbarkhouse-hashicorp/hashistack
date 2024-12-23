job "traefik" {
  datacenters = ["dc1"]
  node_pool = "all"
  type        = "system"

  group "traefik" {
    count = 1

    network {
      port "http" {
        static = 8080
      }

      port "api" {
        static = 8081
      }
      port "ping" {
        static = 8082
      }
    }

    service {
      name = "traefik"
			address = "${attr.unique.platform.aws.public-ipv4}"
      port = "http"
      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
      check {
        type = "http"
        port = "ping"
        path = "/ping"
        interval = "10s"
        timeout = "2s"
    }
    }

    task "traefik" {
      driver = "docker"
      vault {
         change_mode   = "restart"
      }
      config {
        image        = "traefik"
        network_mode = "host"

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
        ]
      }

      template {
        data = <<EOF
[entryPoints]
    [entryPoints.http]
    address = ":8080"
    [entryPoints.traefik]
    address = ":8081"
    [entryPoints.ping]
    address = ":8082"

[api]
    dashboard = true
    insecure  = true
        
[ping]
  entryPoint = "ping"

# Enable Consul Catalog configuration backend.
[providers.consulCatalog]
    prefix           = "traefik"
    exposedByDefault = false

    [providers.consulCatalog.endpoint]
      address = "127.0.0.1:8500"
      scheme  = "http"
      token= "{{with secret "consul/creds/reader-role"}}{{.Data.token}}{{end}}"
EOF

        destination = "local/traefik.toml"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}