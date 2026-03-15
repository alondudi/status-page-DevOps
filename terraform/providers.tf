terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" 
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
  backend "s3" {
    bucket = "aa-statuspage-terraform-state" # השם הייחודי שנתת ל-Bucket
    key    = "terraform.tfstate"                     # שם הקובץ שיישמר בענן
    region = "us-east-1"                             # האזור שבו יצרת את ה-Bucket
  }
}


provider "aws" {
  region = "us-east-1"
  
  default_tags {
    tags = {
      Project     = "StatusPage"
      name        = "status-page-aa"
      ManagedBy   = "Terraform"
    }
  }
}