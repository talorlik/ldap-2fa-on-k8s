output "ebs_pvc_name" {
  value = kubernetes_persistent_volume_claim_v1.ebs_pvc.metadata[0].name
}
