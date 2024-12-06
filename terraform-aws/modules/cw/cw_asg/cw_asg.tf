
variable "aws_autoscaling_group_name" {
  default = ""
}


resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "high-cpu-utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EC2 CPU utilization"
  dimensions = {
    AutoScalingGroupName = var.aws_autoscaling_group_name
  }

  alarm_actions = [aws_autoscaling_policy.replace_action.arn]
}

resource "aws_autoscaling_policy" "replace_action" {
  name                   = "replace-instance-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 1
  autoscaling_group_name = var.aws_autoscaling_group_name
}
