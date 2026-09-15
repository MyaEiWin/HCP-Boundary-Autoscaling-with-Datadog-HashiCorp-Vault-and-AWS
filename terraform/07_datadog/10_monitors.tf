resource "datadog_monitor" "sessions_high" {
  name    = "Boundary active sessions high"
  type    = "metric alert"
  query   = "avg(last_5m):sum:boundary.active_sessions{service:boundary} > 5"
  message = "Boundary sessions are high. ${var.scale_out_notification}"
  monitor_thresholds { critical = 5 }
}

resource "datadog_monitor" "sessions_low" {
  name    = "Boundary active sessions low"
  type    = "metric alert"
  query   = "avg(last_10m):sum:boundary.active_sessions{service:boundary} < 2"
  message = "Boundary sessions are low. ${var.scale_in_notification}"
  monitor_thresholds { critical = 2 }
}

