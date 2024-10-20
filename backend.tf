terraform {
  backend "s3" {
    encrypt        = true
    bucket         = "s3-terraform-tfstate"
    dynamodb_table = "terraform-locks"
    region         = "region"
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "arn:aws:eks:region:account-id:cluster/cluster_name"
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "arn:aws:eks:region:account-id:cluster/cluster_name"
  }
}