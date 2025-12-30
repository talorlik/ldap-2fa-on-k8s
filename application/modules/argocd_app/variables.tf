variable "app_name" {
  description = "Name of the ArgoCD Application"
  type        = string
}

variable "argocd_namespace" {
  description = "Kubernetes namespace where ArgoCD Application will be created"
  type        = string
  default     = "argocd"
}

variable "argocd_project_name" {
  description = "ArgoCD project name for the Application"
  type        = string
  default     = "default"
}

variable "cluster_name_in_argo" {
  description = "Name of the cluster in ArgoCD (from cluster registration secret)"
  type        = string
}

variable "repo_url" {
  description = "Git repository URL containing application manifests"
  type        = string
}

variable "target_revision" {
  description = "Git branch, tag, or commit to sync (default: HEAD)"
  type        = string
  default     = "HEAD"
}

variable "repo_path" {
  description = "Path within the repository to the application manifests"
  type        = string
}

variable "destination_namespace" {
  description = "Target Kubernetes namespace for the application"
  type        = string
}

variable "destination_server" {
  description = "Optional Kubernetes server URL (defaults to cluster_name_in_argo)"
  type        = string
  default     = null
}

variable "app_labels" {
  description = "Labels to apply to the ArgoCD Application resource"
  type        = map(string)
  default     = {}
}

variable "app_annotations" {
  description = "Annotations to apply to the ArgoCD Application resource"
  type        = map(string)
  default     = {}
}

variable "sync_policy" {
  description = "Sync policy configuration for the Application"
  type = object({
    automated = object({
      prune       = bool
      self_heal   = bool
      allow_empty = optional(bool, false)
    })
    sync_options = optional(list(string), ["CreateNamespace=true"])
    retry = optional(object({
      limit = number
      backoff = optional(object({
        duration     = string
        factor       = number
        max_duration = string
      }))
    }))
  })
  default = null
}

variable "ignore_differences" {
  description = "List of ignore differences configurations"
  type = list(object({
    group                 = optional(string)
    kind                  = optional(string)
    name                  = optional(string)
    namespace             = optional(string)
    jsonPointers          = optional(list(string))
    jqPathExpressions     = optional(list(string))
    managedFieldsManagers = optional(list(string))
  }))
  default = []
}

variable "revision_history_limit" {
  description = "Number of application revisions to keep in history"
  type        = number
  default     = 5
}

variable "helm_config" {
  description = "Helm-specific configuration (for Helm charts)"
  type = object({
    value_files = optional(list(string), [])
    parameters = optional(list(object({
      name         = string
      value        = string
      force_string = optional(bool, false)
    })), [])
    release_name = optional(string)
  })
  default = null
}

variable "kustomize_config" {
  description = "Kustomize-specific configuration"
  type = object({
    images             = optional(list(string), [])
    common_labels      = optional(map(string), {})
    common_annotations = optional(map(string), {})
    patches = optional(list(object({
      path  = string
      patch = string
      target = optional(object({
        group     = string
        kind      = string
        name      = string
        namespace = optional(string)
      }))
    })), [])
  })
  default = null
}

variable "directory_config" {
  description = "Directory-specific configuration (for plain manifests)"
  type = object({
    recurse = optional(bool, true)
    include = optional(string)
    exclude = optional(string)
    jsonnet = optional(object({
      libs = optional(list(string), [])
      tlas = optional(list(object({
        name  = string
        value = string
        code  = optional(bool, false)
      })), [])
      ext_vars = optional(list(object({
        name  = string
        value = string
        code  = optional(bool, false)
      })), [])
    }))
  })
  default = null
}

