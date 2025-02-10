job "hello-world-podman" {
  datacenters = ["dc1"]
  node_pool = "x86"
  type = "service"

  group "hello-world-group" {
    count = 1

    network {
      port "http" {
        to     = 80
      }
      mode = "bridge"
    }
 
    
    service {
      name = "hello-world-podman"
      port = "http"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.helloworldpodman.rule=PathPrefix(`/hello-world-podman`)",
        ]
      address = "${attr.unique.platform.aws.public-ipv4}"
      check {
        name     = "hello-world-podman"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }


    task "hello-world-server" {
      driver = "podman"

      config {
        image = "docker.io/library/httpd"
        ports = ["http"]
        #mount {
        #  type   = "bind"
        #  source = "local"
        #  target = "/usr/local/apache2/htdocs"
        volumes = [
          "/opt/nomad/alloc/${NOMAD_ALLOC_ID}/${NOMAD_TASK_NAME}/local:/usr/local/apache2/htdocs"
          ]
        }
      
      template {
        data = <<EOF
        <html><body><h1>Hello World!</h1><br><a href="contact.html">Contact Us</a></body></html>
     EOF
        destination = "${NOMAD_TASK_DIR}/hello-world-podman/index.html"
      }
      template {
        data = <<EOF
        <html><body><h1>Contact Us</h1></body></html>
     EOF
        destination = "${NOMAD_TASK_DIR}/hello-world-podman/contact.html"
      }
  }
  }
  }