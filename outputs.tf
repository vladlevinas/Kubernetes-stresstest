output "cluster_id" {
  value = digitalocean_kubernetes_cluster.main.id
}

output "cluster_endpoint" {
  value = digitalocean_kubernetes_cluster.main.endpoint
}

output "kubeconfig_path" {
  value = local_file.kubeconfig.filename
}

output "node_ips" {
  description = "Get node external IPs: kubectl get nodes -o wide"
  value       = "kubectl get nodes -o wide --kubeconfig=${local_file.kubeconfig.filename}"
}

output "chaos_mesh_dashboard" {
  value = "http://<NODE-IP>:${var.nodeport_chaos_mesh}"
}

output "goldilocks_dashboard" {
  value = "http://<NODE-IP>:${var.nodeport_goldilocks}"
}

output "chaos_mesh_token_cmd" {
  value = "kubectl create token chaos-dashboard-admin -n chaos-mesh --kubeconfig=${local_file.kubeconfig.filename}"
}

output "kube_bench_logs_cmd" {
  value = "kubectl logs job/kube-bench --kubeconfig=${local_file.kubeconfig.filename}"
}

output "trivy_report_cmd" {
  value = "kubectl get vulnerabilityreports -A --kubeconfig=${local_file.kubeconfig.filename}"
}

output "monthly_cost" {
  value = "~$24/mo — 2x s-1vcpu-2gb nodes"
}
