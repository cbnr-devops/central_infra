resource "aws_prometheus_workspace" "this" {
  alias = "${var.env}-observability"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "adot_amp_policy" {
  name        = "${var.env}-adot-amp-policy"
  description = "Allow ADOT collector to write metrics to AMP workspace"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aps:RemoteWrite",
          "aps:GetSeries",
          "aps:GetLabels",
          "aps:GetMetricMetadata"
        ]
        Resource = aws_prometheus_workspace.this.arn
      }
    ]
  })
}

locals {
  oidc_provider_url         = replace(var.oidc_provider_arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/", "")
  amp_remote_write_endpoint = "https://aps-workspaces.${var.region}.amazonaws.com/workspaces/${aws_prometheus_workspace.this.id}/api/v1/remote_write"
  loki_s3_endpoint          = "s3.${var.region}.amazonaws.com"
}

resource "aws_iam_role" "adot_irsa_role" {
  name = "${var.env}-adot-amp-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:observability:aws-otel-collector"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "adot_irsa_attachment" {
  role       = aws_iam_role.adot_irsa_role.name
  policy_arn = aws_iam_policy.adot_amp_policy.arn
}

resource "aws_s3_bucket" "loki" {
  bucket = "${var.env}-loki-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Environment = var.env
    Component   = "loki"
  }
}

resource "aws_s3_bucket_versioning" "loki" {
  bucket = aws_s3_bucket.loki.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_policy" "loki_s3_policy" {
  name        = "${var.env}-loki-s3-policy"
  description = "Allow Loki to use S3 bucket for log storage"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.loki.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.loki.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role" "loki_irsa_role" {
  name = "${var.env}-loki-s3-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:logging:loki"
          }
        }
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "loki_irsa_attachment" {
  role       = aws_iam_role.loki_irsa_role.name
  policy_arn = aws_iam_policy.loki_s3_policy.arn
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = [
        "eks",
        "get-token",
        "--cluster-name",
        var.cluster_name
      ]
    }
  }
}


resource "helm_release" "adot_collector" {
  name       = "aws-otel-collector"
  namespace  = "observability"
  chart      = "aws-otel-collector"
  repository = "https://aws-observability.github.io/aws-otel-helm-chart"
  version    = "0.31.0" 

  create_namespace = true

  values = [
    yamlencode({
      mode = "deployment"

      serviceAccount = {
        create = true
        name   = "aws-otel-collector"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.adot_irsa_role.arn
        }
      }

      config = {
        receivers = {
          prometheus = {
            config = {
              global = {
                scrape_interval = "15s"
              }
              scrape_configs = [
                {
                  job_name = "kubernetes-pods"
                  kubernetes_sd_configs = [
                    {
                      role = "pod"
                    }
                  ]
                  relabel_configs = [
                    {
                      source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
                      action        = "keep"
                      regex         = "true"
                    }
                  ]
                }
              ]
            }
          }
        }

        exporters = {
          prometheusremotewrite = {
            endpoint = local.amp_remote_write_endpoint
            auth = {
              authenticator = "sigv4auth"
            }
          }
        }

        extensions = {
          sigv4auth = {
            region  = var.region
            service = "aps"
          }
        }

        service = {
          extensions = ["sigv4auth"]
          pipelines = {
            metrics = {
              receivers  = ["prometheus"]
              exporters  = ["prometheusremotewrite"]
            }
          }
        }
      }
    })
  ]
}


resource "helm_release" "loki" {
  name       = "loki"
  namespace  = "logging"
  chart      = "loki"
  repository = "https://grafana.github.io/helm-charts"
  version    = "5.42.0" 

  create_namespace = true

  values = [
    yamlencode({
      deploymentMode = "SingleBinary"

      serviceAccount = {
        create = true
        name   = "loki"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.loki_irsa_role.arn
        }
      }

      loki = {
        auth_enabled = false

        schema_config = {
          configs = [
            {
              from         = "2023-01-01"
              store        = "boltdb-shipper"
              object_store = "aws"
              schema       = "v11"
              index        = {
                prefix = "index_"
                period = "24h"
              }
            }
          ]
        }

        storage_config = {
          aws = {
            s3        = "s3://${aws_s3_bucket.loki.bucket}"
            endpoint  = local.loki_s3_endpoint
            region    = var.region
            s3forcepathstyle = true
          }

          boltdb_shipper = {
            shared_store = "aws"
            active_index_directory = "/var/loki/index"
            cache_location         = "/var/loki/cache"
          }
        }

        compactor = {
          working_directory = "/var/loki/compactor"
          shared_store      = "aws"
        }
      }

      persistence = {
        enabled = true
        size    = "10Gi"
      }
    })
  ]
}


resource "helm_release" "alloy" {
  name       = "alloy"
  namespace  = "logging"
  chart      = "alloy"
  repository = "https://grafana.github.io/helm-charts"
  version    = "0.4.0" 

  create_namespace = false 

  values = [
    yamlencode({
      alloy = {
        k8sServiceAccount = {
          create = true
          name   = "alloy"
        }

        configMap = {
          create = true
          content = <<-EOF
            logging {
              level  = "info"
              format = "logfmt"
            }

            discovery.kubernetes "pods" {
              role = "pod"
            }

            loki.source.kubernetes "pods" {
              targets    = discovery.kubernetes.pods.targets
              forward_to = [loki.write.default.receiver]
            }

            loki.write "default" {
              endpoint {
                url = "http://loki-gateway.logging.svc.cluster.local/loki/api/v1/push"
              }

              external_labels = {
                cluster   = "${var.cluster_name}",
                env       = "${var.env}"
              }
            }
          EOF
        }
      }
    })
  ]
}


resource "helm_release" "grafana" {
  name       = "grafana"
  namespace  = "observability"
  chart      = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  version    = "7.3.0" 

  create_namespace = true

  values = [
    yamlencode({
      adminUser     = "admin"
      adminPassword = "admin" 

      service = {
        type = "ClusterIP"
      }

      persistence = {
        enabled = true
        size    = "10Gi"
      }

      serviceAccount = {
        create = true
        name   = "grafana"
      }

      datasources = {
        datasources = [
          {
            name      = "AMP"
            type      = "prometheus"
            access    = "proxy"
            isDefault = true
            url       = "https://aps-workspaces.${var.region}.amazonaws.com/workspaces/${aws_prometheus_workspace.this.id}"
            jsonData = {
              httpMethod = "POST"
              sigV4Auth  = true
              sigV4Region = var.region
              sigV4Service = "aps"
            }
          },
          {
            name   = "Loki"
            type   = "loki"
            access = "proxy"
            url    = "http://loki-gateway.logging.svc.cluster.local"
          }
        ]
      }

      ingress = {
        enabled = false
      }
    })
  ]
}