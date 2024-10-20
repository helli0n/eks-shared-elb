resource "kubernetes_namespace" "nginx" {
  metadata {
    name = "test-fargate-nginx"
  }
}

resource "aws_eks_fargate_profile" "fargate_profile_ngnix" {
  cluster_name           = "cluster_name"
  fargate_profile_name   = kubernetes_namespace.nginx.metadata[0].name
  pod_execution_role_arn = aws_iam_role.eks-fargate-profile.arn

  # These subnets must have the following resource tag:
  # kubernetes.io/cluster/<CLUSTER_NAME>.
  subnet_ids = [
    "subnet-id1",
    "subnet-id2",
    "subnet-id3"
  ]

  selector {
    namespace = kubernetes_namespace.nginx.metadata[0].name
    labels = {
      application = "nginx"
    env = "test" }
  }
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx-deployment"
    namespace = kubernetes_namespace.nginx.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        application = "nginx"
        env         = "test"
      }
    }

    template {
      metadata {
        labels = {
          application = "nginx"
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
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx-service"
    namespace = kubernetes_namespace.nginx.metadata[0].name
  }

  spec {
    selector = {
      application = "nginx"
      env         = "test"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "NodePort"
  }
}

resource "kubernetes_ingress_v1" "nginx" {
  metadata {
    name      = "nginx-ingress"
    namespace = kubernetes_namespace.nginx.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                = "alb"
      "alb.ingress.kubernetes.io/group.name"       = "shared"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
      "alb.ingress.kubernetes.io/success-codes"    = "200"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/"
      "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
      "alb.ingress.kubernetes.io/tags"                     = "Environment=dev,Application=app"
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "idle_timeout.timeout_seconds=600"
      "alb.ingress.kubernetes.io/certificate-arn"          = "arn:aws:acm:region:account-id:certificate/cert-id"
      "alb.ingress.kubernetes.io/listen-ports"             = "[{\"HTTPS\":443}, {\"HTTP\":80}]"
      "alb.ingress.kubernetes.io/actions.ssl-redirect"     = "{'Type': 'redirect', 'RedirectConfig': { 'Protocol': 'HTTPS', Port: '443', StatusCode: 'HTTP_301'}}"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      host = "nginx.eod.env.example.com"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.nginx.metadata[0].name
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