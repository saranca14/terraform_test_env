provider "aws" {
  region = "us-east-1"
  assume_role {
    role_arn     = "arn:aws:iam::751555341958:role/role_for_tf"
    session_name = "demo_session"
  }
}