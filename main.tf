terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 2.0"
    }
  }
}

variable "grafana_password" {
  description = "Parola de admin pentru Grafana"
  type        = string
  sensitive   = true 
}

provider "grafana" {
  url  = "http://localhost:3000"
  auth = "admin:${var.grafana_password}" 
}

resource "grafana_data_source" "prom_petclinic" {
  name        = "DS_PROMETHEUS"
  type        = "prometheus"
  url         = "http://prometheus:9090" 
  access_mode = "proxy"
}

resource "grafana_dashboard" "jvm_jmx" {
  depends_on = [grafana_data_source.prom_petclinic]

  config_json = file("${path.module}/jvm-dashboard-10519.json")
  overwrite   = true
}