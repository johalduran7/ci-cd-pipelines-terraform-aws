# CloudWatch Log Group for CloudWatch Logs Daemon, CloudWatch Agent and    Unified
resource "aws_cloudwatch_log_group" "app_log_group" {
  name              = "/${var.env}/app"
  retention_in_days = 1 # Retain logs for 7 days

}

# CloudWatch Log Stream for CloudWatch Logs Daemon
resource "aws_cloudwatch_log_stream" "app_log_stream" {
  name           = "${var.env}-app"
  log_group_name = aws_cloudwatch_log_group.app_log_group.name
}


