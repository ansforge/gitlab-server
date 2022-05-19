job "forge-gitlab-runner-java" {
    datacenters = ["${datacenter}"]
    type = "service"

    vault {
        policies = ["forge"]
        change_mode = "restart"
    }
    group "gitlab-runner-java-server" {
        count ="1"

        restart {
            attempts = 3
            delay = "60s"
            interval = "1h"
            mode = "fail"
        }

        network {
            port "gitlab_runner" { to = 8093 }
        }

        constraint {
            attribute = "$\u007Bnode.class\u007D"
            value     = "data"
        }

        task "gitlab-runner-java-autoregistered" {
            driver = "docker"

            template {

            data = <<EOH
{{ with secret "forge/gitlab-runner" }}
TOKEN_GITLAB_RUNNER="{{ .Data.data.token_gitlab_runner }}"
{{ end }}
EOH
                destination = "secrets/gitlab-runner.env"
                change_mode = "restart"
                env = true
            }

            config {

                image   = "${image}:${tag}"
                ports   = ["gitlab_runner"]
                extra_hosts = ["${external_url_gitlab_hostname}:$\u007BNOMAD_IP_gitlab_runner\u007D"]

                command = "register"
                args = [
                    "--non-interactive",
                    "--executor",
                    "docker",
                    "--docker-image",
                    "maven",
                    "--url",
                    "http://${external_url_gitlab_hostname}",
                    "--registration-token",
                    "$\u007BTOKEN_GITLAB_RUNNER\u007D",
                    "--description",
                    "runner docker java",
                    "--run-untagged=true",
                    "--locked=false",
                    "--access-level=not_protected"
                ]

                mount {
                    type = "volume"
                    target = "/etc/gitlab-runner"
                    source = "forge-gitlab-runner-config"
                    readonly = false
                    volume_options {
                        no_copy = false
                        driver_config {
                            name = "pxd"
                            options {
                                io_priority = "high"
                                size = 1
                                repl = 2
                            }
                        }
                    }
                }

                mount {
                    type = "bind"
                    target = "/var/run/docker.sock"
                    source = "/var/run/docker.sock"
                    readonly = false
                    bind_options {
                        propagation = "rshared"
                    }
                }
            }
            lifecycle {
                hook = "prestart"
                sidecar = "false"
            }

            resources {
                cpu    = 1000
                memory = 1024
            }
        }

        task "gitlab-runner-java" {
            driver = "docker"

            config {

                image   = "${image}:${tag}"
                ports   = ["gitlab_runner"]

                mount {
                    type = "volume"
                    target = "/etc/gitlab-runner"
                    source = "forge-gitlab-runner-config"
                    readonly = false
                    volume_options {
                        no_copy = false
                        driver_config {
                            name = "pxd"
                            options {
                                io_priority = "high"
                                size = 1
                                repl = 2
                            }
                        }
                    }
                }

                mount {
                    type = "bind"
                    target = "/var/run/docker.sock"
                    source = "/var/run/docker.sock"
                    readonly = false
                    bind_options {
                        propagation = "rshared"
                    }
                }
            }

            resources {
                cpu    = 1000
                memory = 1024
            }
        }
    }
}