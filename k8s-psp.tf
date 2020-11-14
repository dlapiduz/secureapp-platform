resource "kubernetes_pod_security_policy" "restricted_psp" {
  metadata {
    name = "restricted"
    annotations = {
      "seccomp.security.alpha.kubernetes.io/allowedProfileNames" = "docker/default,runtime/default"
      "apparmor.security.beta.kubernetes.io/allowedProfileNames" = "runtime/default"
      "seccomp.security.alpha.kubernetes.io/defaultProfileName" = "runtime/default"
      "apparmor.security.beta.kubernetes.io/defaultProfileName" = "runtime/default"
    }
  }
  spec {
    privileged                 = false
    allow_privilege_escalation = false
    host_network = false
    host_ipc = false
    host_pid = false
    required_drop_capabilities = ["ALL"]

    volumes = [
      "configMap",
      "emptyDir",
      "projected",
      "secret",
      "downwardAPI",
      "persistentVolumeClaim",
    ]

    run_as_user {
      rule = "MustRunAsNonRoot"
    }

    se_linux {
      rule = "RunAsAny"
    }

    supplemental_groups {
      rule = "MustRunAs"
      range {
        min = 1
        max = 65535
      }
    }

    fs_group {
      rule = "MustRunAs"
      range {
        min = 1
        max = 65535
      }
    }

    read_only_root_filesystem = false
  }
}


resource "kubernetes_cluster_role" "restricted_psp_role" {
  metadata {
    name = "psp:restricted"
  }
  rule {
    api_groups = ["policy"]
    verbs = ["use"]
    resources = ["podsecuritypolicies"]
    resource_names = ["restricted"]
  }
}
