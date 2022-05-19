job "forge-gitlab" {
    datacenters = ["${datacenter}"]
    type = "service"

    vault {
        policies = ["forge"]
        change_mode = "restart"
    }
    group "gitlab-server" {
        count ="1"
        
        restart {
            attempts = 3
            delay = "60s"
            interval = "1h"
            mode = "fail"
        }
        
        constraint {
            attribute = "$\u007Bnode.class\u007D"
            value     = "data"
        }

        network {
            port "gitlab" { to = 80 }
            port "gitlab-https" { to = 443 }
            port "gitlab-ssh" { to = 22 }
        }

        task "prep-config" {
            driver = "docker"

            config {
                image = "busybox:latest"
                mount {
                    type = "volume"
                    target = "/etc/gitlab"
                    source = "forge-gitlab-config"
                    readonly = false
                    volume_options {
                        no_copy = false
                        driver_config {
                            name = "pxd"
                            options {
                                io_priority = "high"
                                size = 10
                                repl = 2
                            }
                        }
                    }
                }
                command = "sh"
                args = ["-c", "ln -sf /secrets/gitlab.ans.rb /etc/gitlab/gitlab.rb"]
            }
            resources {
                cpu = 100
                memory = 64
            }
            lifecycle {
                hook = "prestart"
                sidecar = "false"
            }
        }

        task "gitlab" {
            driver = "docker"

            template {
                data = <<EOH
EXTERNAL_URL="${external_url_gitlab_protocole}://${external_url_gitlab_hostname}"
EOH
                destination = "secrets/file.env"
                change_mode = "restart"
                env = true
            }

            template {
                destination = "secrets/gitlab.ans.rb"
                change_mode = "restart"
                data = <<EOH
{{ with secret "forge/gitlab" }}
gitlab_rails['initial_root_password'] = '{{ .Data.data.gitlab_root_password }}'
{{ end }}
gitlab_rails['ldap_enabled'] = true
gitlab_rails['prevent_ldap_sign_in'] = false
gitlab_rails['ldap_servers'] = YAML.load <<-'EOS'
main:
  label: 'LDAP ANS'
{{ range service "ldap-forge" }}
  host: '{{ .Address }}'
  port: {{ .Port }}
{{ end }}
  uid: 'uid'
  encryption: 'plain'
{{ with secret "forge/openldap" }}
  bind_dn: 'cn={{ .Data.data.admin_username }},{{ .Data.data.ldap_root }}'
  password: '{{ .Data.data.admin_password }}'
  base: '{{ .Data.data.ldap_root }}'
{{ end }}
  timeout: 10
  verify_certificates: false
  active_directory: false
  allow_username_or_email_login: false
  lowercase_usernames: false
EOS
                EOH
            }

            config {
                image   = "${image}:${tag}"
                ports   = ["gitlab", "gitlab-https", "gitlab-ssh"]
                volumes = ["name=forge-gitlab-data,io_priority=high,size=5,repl=2:/var/opt/gitlab",
                           "name=forge-gitlab-logs,io_priority=high,size=2,repl=2:/var/log/gitlab",
                           "name=forge-gitlab-config,io_priority=high,size=2,repl=2:/etc/gitlab"]
                volume_driver = "pxd"
            }

            resources {
                cpu    = 10000
                memory = 16000
            }
            
            service {
                name = "$\u007BNOMAD_JOB_NAME\u007D"
                tags = ["urlprefix-${external_url_gitlab_hostname}/"]
                port = "gitlab"
                check {
                    name     = "alive"
                    type     = "tcp"
                    interval = "60s"
                    timeout  = "10s"
                    failures_before_critical = 5
                    port     = "gitlab"
                }
            }
        } 
    }
}