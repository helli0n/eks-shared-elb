resource "kubernetes_namespace" "shared-alb" {
  metadata {
    name = "shared-alb"
  }
}

resource "kubernetes_deployment" "nginx_for_shared_alb" {
  metadata {
    name      = "nginx-for-shared-alb-deployment"
    namespace = kubernetes_namespace.shared-alb.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        application = "nginx_for_shared_alb"
        env         = "test"
      }
    }

    template {
      metadata {
        labels = {
          application = "nginx_for_shared_alb"
          env         = "test"
        }
      }

      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"

          port {
            container_port = 80
          }
          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "0.25"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx_for_shared_alb" {
  metadata {
    name      = "nginx-service-shared"
    namespace = kubernetes_namespace.shared-alb.metadata[0].name
  }

  spec {
    selector = {
      application = "nginx_for_shared_alb"
      env         = "test"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "NodePort"
  }
}

resource "kubernetes_ingress_v1" "nginx_for_shared_alb" {
  metadata {
    name      = "nginx-ingress-shared"
    namespace = kubernetes_namespace.shared-alb.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                        = "alb"
      "alb.ingress.kubernetes.io/group.name"               = "shared"
      "alb.ingress.kubernetes.io/target-type"              = "ip"
      "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
      "alb.ingress.kubernetes.io/ssl-redirect"             = "443"
      "alb.ingress.kubernetes.io/success-codes"            = "200"
      "alb.ingress.kubernetes.io/healthcheck-path"         = "/"
      "alb.ingress.kubernetes.io/backend-protocol"         = "HTTP"
      "alb.ingress.kubernetes.io/tags"                     = "Environment=env_name,Application=app"
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "idle_timeout.timeout_seconds=600"
      "alb.ingress.kubernetes.io/certificate-arn"          = "arn:aws:acm:region:account-id:certificate/cert-id"
      "alb.ingress.kubernetes.io/listen-ports"             = "[{\"HTTPS\":443}, {\"HTTP\":80}]"
      "alb.ingress.kubernetes.io/actions.ssl-redirect"     = "{'Type': 'redirect', 'RedirectConfig': { 'Protocol': 'HTTPS', Port: '443', StatusCode: 'HTTP_301'}}"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      host = "eod.env.example.com"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.nginx_for_shared_alb.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}