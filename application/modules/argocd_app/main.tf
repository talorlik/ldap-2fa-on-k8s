resource "kubernetes_manifest" "argocd_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name        = var.app_name
      namespace   = var.argocd_namespace
      labels      = var.app_labels
      annotations = var.app_annotations
    }
    spec = {
      project = var.argocd_project_name

      source = {
        repoURL        = var.repo_url
        targetRevision = var.target_revision
        path           = var.repo_path
        helm = var.helm_config != null ? {
          valueFiles  = var.helm_config.value_files
          parameters  = var.helm_config.parameters
          releaseName = var.helm_config.release_name
        } : null
        kustomize = var.kustomize_config != null ? {
          images            = var.kustomize_config.images
          commonLabels      = var.kustomize_config.common_labels
          commonAnnotations = var.kustomize_config.common_annotations
          patches           = var.kustomize_config.patches
        } : null
        directory = var.directory_config != null ? {
          recurse = var.directory_config.recurse
          include = var.directory_config.include
          exclude = var.directory_config.exclude
          jsonnet = var.directory_config.jsonnet != null ? {
            libs    = var.directory_config.jsonnet.libs
            tlas    = var.directory_config.jsonnet.tlas
            extVars = var.directory_config.jsonnet.ext_vars
          } : null
        } : null
      }

      destination = {
        name      = var.cluster_name_in_argo
        namespace = var.destination_namespace
        server    = var.destination_server != null ? var.destination_server : null
      }

      syncPolicy = var.sync_policy != null ? {
        automated = var.sync_policy.automated != null ? {
          prune      = var.sync_policy.automated.prune
          selfHeal   = var.sync_policy.automated.self_heal
          allowEmpty = var.sync_policy.automated.allow_empty
        } : null
        syncOptions = var.sync_policy.sync_options
        retry = var.sync_policy.retry != null ? {
          limit = var.sync_policy.retry.limit
          backoff = var.sync_policy.retry.backoff != null ? {
            duration    = var.sync_policy.retry.backoff.duration
            factor      = var.sync_policy.retry.backoff.factor
            maxDuration = var.sync_policy.retry.backoff.max_duration
          } : null
        } : null
      } : null

      ignoreDifferences    = length(var.ignore_differences) > 0 ? var.ignore_differences : null
      revisionHistoryLimit = var.revision_history_limit
    }
  }

  depends_on = var.depends_on_resources
}
