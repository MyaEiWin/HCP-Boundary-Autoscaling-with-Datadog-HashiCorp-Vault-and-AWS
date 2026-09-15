provider "datadog" {
  # Set DATADOG_API_KEY and DATADOG_APP_KEY in the environment.
  api_url = var.datadog_api_url
}

provider "aws" {
  region = var.aws_region
}
