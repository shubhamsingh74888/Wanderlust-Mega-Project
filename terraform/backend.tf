#Backend Configuration
terraform {
  backend "s3" {
    # These values are intentionally left empty here.
    # The actual values come from backend-configs/dev.hcl or prod.hcl
    # This pattern is called "partial configuration"
    # It allows one codebase to deploy to multiple environments
  }
}

