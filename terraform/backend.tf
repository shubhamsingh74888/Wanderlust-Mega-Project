terraform {
  backend "s3" {
    bucket         = "my-s3-bucket-shubham-default" # Match the bucket name you created in remote-infra
    key            = "wanderlust/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "wanderlust-shubham-default"   # Match the DynamoDB table name you created
    encrypt        = true
  }
}
