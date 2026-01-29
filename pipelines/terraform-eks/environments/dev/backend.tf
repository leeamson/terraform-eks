terraform {
  backend "s3" {
    bucket         = "terraform-state-ACCOUNT_ID-dev"  # UPDATE THIS
    key            = "eks-cluster/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-locks-dev"
  }
}
