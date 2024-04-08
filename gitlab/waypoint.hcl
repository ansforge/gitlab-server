project = "forge/gitlab"

labels = { "domaine" = "forge" }

runner {
    enabled = true
    data_source "git" {
        url  = "https://github.com/ansforge/gitlab-server.git"
        ref  = "main"
        path = "gitlab"
        ignore_changes_outside_path = true
    }
}

app "forge/gitlab" {

    build {
        use "docker-pull" {
            image = var.image
            tag   = var.tag
            disable_entrypoint = true
        }
    }
  
    deploy{
        use "nomad-jobspec" {
            jobspec = templatefile("${path.app}/forge-gitlab.nomad.tpl", {
            image   = var.image
            tag     = var.tag
            datacenter = var.datacenter
            external_url_gitlab_hostname = var.external_url_gitlab_hostname
            external_url_gitlab_protocole = var.external_url_gitlab_protocole
            url_proxy_sortant_http = var.url_proxy_sortant_http
            url_proxy_sortant_https = var.url_proxy_sortant_https
            url_proxy_sortant_no_proxy = var.url_proxy_sortant_no_proxy
            })
        }
    }
}

variable "datacenter" {
    type    = string
    default = "test"
}

variable "image" {
    type    = string
    default = "gitlab/gitlab-ce"
}

variable "tag" {
    type    = string
    default = "16.10.1-ce.0"
}

variable "external_url_gitlab_hostname" {
    type    = string
    default = "gitlab.forge.asipsante.fr"
}

variable "external_url_gitlab_protocole" {
    type    = string
    default = "https"
}

variable "url_proxy_sortant_http" {
    type    = string
    default = "http://c-ac-proxy01.asip.hst.fluxus.net:3128/"
}

variable "url_proxy_sortant_https" {
    type    = string
    default = "http://c-ac-proxy01.asip.hst.fluxus.net:3128/"
}

variable "url_proxy_sortant_no_proxy" {
    type    = string
    default = ".asip.hst.fluxus.net, .esante.gouv.fr"
}