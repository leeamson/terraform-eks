terraform {
  backend "s3" {
    bucket         = "terraform-state-ACCOUNT_ID-prod"  # UPDATE THIS
    key            = "eks-cluster/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-locks-prod"
  }
}
