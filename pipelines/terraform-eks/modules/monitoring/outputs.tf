output "namespace" {
  value = var.namespace
}

output "release_name" {
  value = helm_release.kube_prometheus_stack.name
}

output "grafana_port_forward_command" {
  value = "kubectl port-forward svc/${var.release_name}-grafana -n ${var.namespace} 3000:80"
}

output "prometheus_port_forward_command" {
  value = "kubectl port-forward svc/${var.release_name}-prometheus -n ${var.namespace} 9090:9090"
}

output "alertmanager_port_forward_command" {
  value = "kubectl port-forward svc/${var.release_name}-alertmanager -n ${var.namespace} 9093:9093"
}
