terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" 
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
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
    bucket = "aa-statuspage-terraform-state"
    key    = "terraform.tfstate"                    
    region = "us-east-1"   
    dynamodb_table = "terraform-state-lock-AA"                       
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