job "forge-gitlab" {
    datacenters = ["${datacenter}"]
    type = "service"

    update {
        # max_parallel      = 3
        health_check      = "checks"
        min_healthy_time  = "10s"
        healthy_deadline  = "10m"
        progress_deadline = "15m"
        # auto_revert       = true
        # auto_promote      = true
        # canary            = 1
        # stagger           = "30s"
    }

    vault {
        policies = ["forge","smtp"]
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

            # log-shipper
            leader = true

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
external_url "${external_url_gitlab_protocole}://${external_url_gitlab_hostname}"
nginx['listen_port'] = 80
nginx['listen_https'] = false

{{ with secret "forge/gitlab" }}
gitlab_rails['initial_root_password'] = '{{ .Data.data.gitlab_root_password }}'
{{ end }}
gitlab_rails['ldap_enabled'] = true
gitlab_rails['prevent_ldap_sign_in'] = false
gitlab_rails['ldap_servers'] = YAML.load <<-'EOS'
main:
  label: 'LDAP ANS'
{{ range service "openldap-forge" }}
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
prometheus['enable'] = false
# Configuration vers le proxy sortant de l'ANS
gitlab_rails['env'] = {
  "http_proxy" => "${url_proxy_sortant_http}",
  "https_proxy" => "${url_proxy_sortant_https}",
  "no_proxy" => "${url_proxy_sortant_no_proxy}"
}
gitaly['env'] = {
    "http_proxy" => "${url_proxy_sortant_http}",
    "https_proxy" => "${url_proxy_sortant_https}",
    "no_proxy" => "${url_proxy_sortant_no_proxy}"
}
gitlab_workhorse['env'] = {
    "http_proxy" => "${url_proxy_sortant_http}",
    "https_proxy" => "${url_proxy_sortant_https}",
    "no_proxy" => "${url_proxy_sortant_no_proxy}"
}

# Configuration pour l'envoi de mails
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = {{ with secret "services-infrastructure/smtp" }}'{{.Data.data.host}}'{{end}}
gitlab_rails['smtp_port'] = {{ with secret "services-infrastructure/smtp" }}'{{.Data.data.port}}'{{end}}
gitlab_rails['smtp_domain'] = 'localhost'
gitlab_rails['smtp_tls'] = false
gitlab_rails['smtp_openssl_verify_mode'] = 'none'
gitlab_rails['smtp_enable_starttls_auto'] = false
gitlab_rails['smtp_ssl'] = false
gitlab_rails['smtp_force_ssl'] = false
gitlab_rails['gitlab_email_from'] = 'gitlab@esante.gouv.fr'
gitlab_rails['gitlab_email_reply_to'] = 'noreply@esante.gouv.fr'

                EOH
            }

            config {
                extra_hosts = [ "jenkins.internal:$\u007Battr.unique.network.ip-address\u007D"
                              ]
                image   = "${image}:${tag}.${tag_patch}${tag_suffixe}"
                shm_size = 268435456
                ports   = ["gitlab", "gitlab-https", "gitlab-ssh"]
                volumes = ["name=forge-gitlab-data,io_priority=high,size=40,repl=2:/var/opt/gitlab",
                           "name=forge-gitlab-logs,io_priority=high,size=2,repl=2:/var/log/gitlab",
                           "name=forge-gitlab-config,io_priority=high,size=2,repl=2:/etc/gitlab"]
                volume_driver = "pxd"
            }

            resources {
                cpu    = 6000
                memory = 12288
            }
            
            service {
                name = "$\u007BNOMAD_JOB_NAME\u007D"
                tags = ["urlprefix-${external_url_gitlab_hostname}/",
                        "urlprefix-gitlab.internal/"
                       ]
                port = "gitlab"
                check {
                    name     = "alive"
                    type     = "tcp"
                    interval = "120s" #60s
                    timeout  = "5m" #10s
                    failures_before_critical = 10 #5
                    port     = "gitlab"
                }
            }
        }

        # log-shipper
        task "log-shipper" {
            driver = "docker"
            restart {
                    interval = "3m"
                    attempts = 5
                    delay    = "15s"
                    mode     = "delay"
            }
            meta {
                INSTANCE = "$\u007BNOMAD_ALLOC_NAME\u007D"
            }
            template {
                data = <<EOH
REDIS_HOSTS = {{ range service "PileELK-redis" }}{{ .Address }}:{{ .Port }}{{ end }}
PILE_ELK_APPLICATION = GITLAB 
EOH
                destination = "local/file.env"
                change_mode = "restart"
                env = true
            }
            config {
                image = "ans/nomad-filebeat:8.2.3-2.0"
            }
            resources {
                cpu    = 50
                memory = 100
            }
        } #end log-shipper  
    }
}
