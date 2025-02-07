#!/bin/bash
dnf update -y
dnf install -y docker
systemctl start docker
systemctl enable docker

AccountId=$(curl -s http://169.254.169.254/latest/meta-data/identity-credentials/ec2/info | jq -r .AccountId)
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $AccountId.dkr.ecr.us-east-1.amazonaws.com
APP_VERSION=$(aws ssm get-parameter --name "/app/dev/app_version" --query "Parameter.Value" --output text)
APP_VERSION=$(echo $APP_VERSION | cut -d "v" -f3)
ECR_REPO_NAME=$(aws ssm get-parameter --name "/app/dev/ecr_repository_name" --query "Parameter.Value" --output text)
sudo chmod 666 /var/run/docker.sock
docker pull $AccountId.dkr.ecr.us-east-1.amazonaws.com/$ECR_REPO_NAME:$APP_VERSION
docker run -t -d -p 3000:3000 --name $ECR_REPO_NAME $AccountId.dkr.ecr.us-east-1.amazonaws.com/$ECR_REPO_NAME:$APP_VERSION

yum update -y
yum install -y amazon-cloudwatch-agent
yum install -y amazon-cloudwatch-agent httpd

# Start Apache Server
systemctl start httpd
systemctl enable httpd
echo "Hello World from Apache running on $(curl http://169.254.169.254/latest/meta-data/instance-id) " > /var/www/html/index.html

# Configure Apache to log in JSON format
echo 'LogFormat "{   \"LogType\": \"access\",   \"time\": \"%%{%Y-%m-%dT%H:%M:%S%z}t\",   \"remote_ip\": \"%a\",   \"host\": \"%v\",   \"method\": \"%m\",   \"url\": \"%U\",   \"query\": \"%q\",   \"protocol\": \"%H\",   \"status\": \"%>s\",   \"bytes_sent\": \"%B\",   \"referer\": \"%%{Referer}i\",   \"user_agent\": \"%%{User-Agent}i\",   \"response_time_microseconds\": \"%D\",   \"forwarded_for\": \"%%{X-Forwarded-For}i\",   \"http_version\": \"%H\",   \"request\": \"%r\" }" json' > /etc/httpd/conf.d/custom_log_format.conf
echo 'CustomLog /var/log/httpd/access_log json' >> /etc/httpd/conf.d/custom_log_format.conf
systemctl restart httpd


# Ensure Apache's access log file exists
if [ ! -f /var/log/httpd/access_log ]; then
    touch /var/log/httpd/access_log
fi


# Set the region in the CloudWatch Agent configuration file
sed -i 's/region = .*/region = ${var.aws_region}/' /etc/awslogs/awscli.conf

# Generate Logs Every Minute
echo "* * * * * root echo '{\"LogType\": \"sample_logs\", \"message\": \"Sample log generated at $(date --iso-8601=seconds)\"} frommm AWS CloudWatch Agent' >> /var/log/sample_logs" >> /etc/cron.d/generate_logs
chmod 0644 /etc/cron.d/generate_logs

# Start CloudWatch Agent

# Create CloudWatch Agent Configuration File in the correct directory
cat <<EOT > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
    "agent":{
        "run_as_user":"root"
    },
    "logs": {
        "logs_collected": {
        "files": {
            "collect_list": [
            {
                "file_path": "/var/log/messages",
                "log_group_name": "${aws_cloudwatch_log_group.app_log_group.name}",
                "log_stream_name": "${aws_cloudwatch_log_stream.app_log_stream.name}",
                "timestamp_format": "%b %d %H:%M:%S.%f"
            },
            {
                "file_path": "/var/log/sample_logs",
                "log_group_name": "${aws_cloudwatch_log_group.app_log_group.name}",
                "log_stream_name": "${aws_cloudwatch_log_stream.app_log_stream.name}",
                "timestamp_format": "%b %d %H:%M:%S.%f"
            },
            {
                "file_path": "/var/log/httpd/access_log",
                "log_group_name": "${aws_cloudwatch_log_group.app_log_group.name}",
                "log_stream_name": "${aws_cloudwatch_log_stream.app_log_stream.name}",
                "timestamp_format": "%b %d %H:%M:%S.%f"
            }                
            ]
        }
        }
    }
}

EOT

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a start -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
