output "ebs_pvc_name" {
  value = kubernetes_persistent_volume_claim_v1.ebs_pvc.metadata[0].name
}

output "ebs_storage_class_name" {
  value = kubernetes_storage_class.ebs.metadata[0].name
}
