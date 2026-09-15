variable "datadog_api_url" {
  type    = string
  default = "https://api.datadoghq.com/"
}
variable "scale_out_notification" { type = string }
variable "scale_in_notification" { type = string }
