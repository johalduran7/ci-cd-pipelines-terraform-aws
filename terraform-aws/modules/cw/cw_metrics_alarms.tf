
# Basic alarm based on a basic metric such as CPU
# Create a CloudWatch alarm for CPU utilization, it will terminate the ec2 instance if the limit is breached
# triger the alarm: $ aws cloudwatch set-alarm-state --alarm-name "high_cpu_utilization" --state-value ALARM --state-reason "testing purposes"
resource "aws_cloudwatch_metric_alarm" "cpu_utilization_alarm" {
  alarm_name          = "high_cpu_utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"                                             # Trigger when CPU utilization exceeds 80%
  alarm_actions       = ["arn:aws:automate:${var.region}:ec2:terminate"] # EC2 terminate action ARN


  dimensions = {
    InstanceId = aws_instance.ec2_cw_logs_daemon.id
  }
  tags = {
    Terraform = "yes"
    aws_saa   = "yes"
  }
}


# Alarm based on a custom metric: We're leveraging the apache instance and its metric created via Unified Agent. However, using the resource aws_cloudwatch_log_metric_filter we can also create a metric to count the number of 4xx http responses

variable "namespace_apache" {
  type    = string
  default = "ApacheMetrics"
}

variable "metric_apache" {
  type    = string
  default = "4xxCount"
}

# when creating custom metric filter, we cannot take action on EC2 instances because they only work with EC2 Per-Instance Metrics. We have to use a lambda function instead. We do can run an action on ASG, we don't need a lambda function for it
resource "aws_cloudwatch_log_metric_filter" "apache_4xx_filter" {
  name           = var.metric_apache
  log_group_name = aws_cloudwatch_log_group.ec2_log_group.name
  pattern        = "{ $.status = \"4*\" }"

  metric_transformation {
    name          = var.metric_apache
    namespace     = var.namespace_apache
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}



module "sns_cw" {
  source = "../sns/sns_cw"

}

module "lambda_cw_alarm" {
  source      = "../lambda/lambda_cw_alarm"
  instance_id = aws_instance.ec2_cw_agent.id
  log_group   = aws_cloudwatch_log_group.ec2_log_group.name
  log_stream  = aws_cloudwatch_log_stream.ec2_log_stream.name
}

# create an alarm and send an SNS notification to my email     whenever   the limit is breached. it also triggers a lambda function
resource "aws_cloudwatch_metric_alarm" "apache_4xx_alarm" {
  alarm_name          = "High4xxCountAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.apache_4xx_filter.name
  namespace           = var.namespace_apache
  period              = 60 # in seconds
  statistic           = "Sum"
  threshold           = 4

  alarm_actions = [module.sns_cw.sns_topic_arn, module.lambda_cw_alarm.lambda_arn]
  tags = {
    Terraform   = "yes"
    aws_dva_c02 = "yes"
  }

}

resource "aws_lambda_permission" "allow_cloudwatch_alarm_invoke" {
  statement_id  = "AllowCloudWatchInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_cw_alarm.lambda_function_name
  principal     = "lambda.alarms.cloudwatch.amazonaws.com"
  source_arn    = aws_cloudwatch_metric_alarm.apache_4xx_alarm.arn
}

## Custom metric and alarm for ASG


variable "metric_apache_asg" {
  type    = string
  default = "4xxCount_asg"
}

resource "aws_cloudwatch_log_metric_filter" "apache_4xx_filter_asg" {
  name           = var.metric_apache_asg
  log_group_name = aws_cloudwatch_log_group.asg_log_group.name
  pattern        = "{ $.status = \"4*\" }"

  metric_transformation {
    name          = var.metric_apache_asg
    namespace     = var.namespace_apache
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}


resource "aws_cloudwatch_metric_alarm" "apache_4xx_alarm_asg" {
  alarm_name          = "High4xxCountAlarm_asg"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.apache_4xx_filter_asg.name
  namespace           = var.namespace_apache
  period              = 60 # in seconds
  statistic           = "Sum"
  threshold           = 4

  alarm_actions = [module.sns_cw.sns_topic_arn, aws_autoscaling_policy.scale_out.arn]
  tags = {
    Terraform   = "yes"
    aws_dva_c02 = "yes"
  }

}

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale-out-instance-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 1
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}




# EC2 writting logs to loggroup/logstream using AWS CloudWatch Logs Daemon (different from AWS CW Agent and Unified Agent)
# Pending to do, install Unified agent and make ASG scale out/in based on a metric and custom metric.
# Make a metric filter and trigger an alarm when certain number of errors are greater than a value. We can use nginx or apache for this.
