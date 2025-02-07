job "hello-world-job" {
  datacenters = ["dc1"]
  node_pool = "x86"
  type = "service"

  group "hello-world-group" {
    count = 1

    network {
      port "http" {
        to     = 80
      }
    }
 
    
    service {
      name = "hello-world"
      port = "http"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.http.rule=PathPrefix(`/hello-world`)",
        #"traefik.http.middlewares.http.stripprefix.prefixes=/hello-world",
        #"traefik.http.routers.http.middlewares=http",
        ]
      address = "${attr.unique.platform.aws.public-ipv4}"
      check {
        name     = "hello-world"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }


    task "hello-world-server" {
      driver = "docker"

      config {
        image = "httpd"
        ports = ["http"]
        mount {
          type   = "bind"
          source = "local"
          target = "/usr/local/apache2/htdocs"
        }
      }
      template {
        data = <<EOF
        <html><body><h1>Hello World!</h1><br><a href="/hello-world/contact.html">Contact Us</a></body></html>
     EOF
        destination = "local/index.html"
      }
      template {
        data = <<EOF
        <html><body><h1>Contact Us</h1></body></html>
     EOF
        destination = "local/contact.html"
      }
  }
  }
}