job "tomcat" {
  datacenters = ["dc1"]
  node_pool   = "x86"
  type        = "service"

  group "tomcat" {
    count = 2
    network {
      port "http" {
      }
    }


    service {
      name = "tomcat"
      port = "http"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.tomcat.rule=PathPrefix(`/sample`)",
        #"traefik.http.middlewares.http.stripprefix.prefixes=/tomcat",
        #"traefik.http.routers.tomcat.middlewares=http",
      ]
      address = "${attr.unique.platform.aws.public-ipv4}"
      check {
        name     = "tomcat"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "tomcat" {
      artifact {
        source      = "https://tomcat.apache.org/tomcat-6.0-doc/appdev/sample/sample.war"
        destination = "/local/webapps"
      }
      artifact {
        #source      = "https://dlcdn.apache.org/tomcat/tomcat-10/v10.1.34/bin/apache-tomcat-10.1.34.tar.gz"
        source = "https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.98/bin/apache-tomcat-9.0.98.tar.gz"
        destination = "/local/tomcat"
        chown = true
      }
      template {
        data        = <<EOH
<?xml version="1.0" encoding="UTF-8"?>
<Server port="-1" shutdown="SHUTDOWN">
  <Listener className="org.apache.catalina.startup.VersionLoggerListener" />
  <Listener className="org.apache.catalina.core.AprLifecycleListener" />
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />
  <GlobalNamingResources>
    <Resource name="UserDatabase" auth="Container"
              type="org.apache.catalina.UserDatabase"
              description="User database that can be updated and saved"
              factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
              pathname="conf/tomcat-users.xml" />
  </GlobalNamingResources>
  <Service name="Catalina">
    <Connector port="${port.http}" protocol="HTTP/1.1"
               connectionTimeout="20000"
               redirectPort="8443" />
    <Engine name="Catalina" defaultHost="localhost">
      <Realm className="org.apache.catalina.realm.LockOutRealm">
        <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
               resourceName="UserDatabase"/>
      </Realm>

      <Host name="localhost"  appBase="${default.context}/webapps"
            unpackWARs="true" autoDeploy="true">
        <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
               prefix="localhost_access_log" suffix=".txt"
               pattern="%h %l %u %t &quot;%r&quot; %s %b" />

      </Host>
    </Engine>
  </Service>
</Server>
EOH
        destination = "/local/tomcat/conf/server.xml"
      }
      env {
        CATALINA_OPTS = "-Dport.http=$NOMAD_PORT_http -Ddefault.context=$NOMAD_TASK_DIR"
        JAVA_HOME     = "/usr/lib/jvm/java-21-openjdk-amd64"
				#CATALINA_HOME = "/local/tomcat/apache-tomcat-10.1.34"
        CATALINA_HOME = "/local/tomcat/apache-tomcat-9.0.98"
      }
      driver = "exec"
      config {
        command = "bash"
        #args = ["-c", "chmod -R 777 /local/tomcat/apache-tomcat-10.1.34 && /local/tomcat/apache-tomcat-10.1.34/bin/catalina.sh run -config /local/tomcat/conf/server.xml"]
        args = ["-c", "chmod -R 777 /local/tomcat/apache-tomcat-9.0.98 && /local/tomcat/apache-tomcat-9.0.98/bin/catalina.sh run -config /local/tomcat/conf/server.xml"]
      }
      resources {
        cpu    = 500
        memory = 500
      }

    }
  }
}