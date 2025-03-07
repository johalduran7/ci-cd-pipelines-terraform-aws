#!/bin/bash
START_TIME=$(date +%s) 
instance_id=$(curl http://169.254.169.254/latest/meta-data/instance-id)
Env=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=Env" --query "Tags[0].Value" --output text)
aws ec2 create-tags --resources $instance_id --tags Key=Name,Value="app-${instance_id}.${Env}.johnportoflio.net"

# Way to name the ec2 at launch, e.g., app-dev-1004
# RANDOM_ID=$(shuf -i 1000-9999 -n 1)

# # Check if the name already exists in AWS (avoid duplicates)
# while aws ec2 describe-instances --filters "Name=tag:Name,Values=dev-app-${RANDOM_ID}" --query "Reservations[*].Instances[*].InstanceId" --output text | grep -q "i-"; do
#   RANDOM_ID=$(shuf -i 1000-9999 -n 1)
# done
# aws ec2 create-tags --resources $(curl -s http://169.254.169.254/latest/meta-data/instance-id) --tags Key=Name,Value="dev-app-${RANDOM_ID}"


dnf update -y
dnf install -y docker
systemctl start docker
systemctl enable docker

AccountId=$(curl -s http://169.254.169.254/latest/meta-data/identity-credentials/ec2/info | jq -r .AccountId)
aws_region=$(curl http://169.254.169.254/latest/meta-data/placement/region)
aws ecr get-login-password | docker login --username AWS --password-stdin $AccountId.dkr.ecr.$aws_region.amazonaws.com
APP_VERSION=$(aws ssm get-parameter --name "/app/${Env}/app_version" --query "Parameter.Value" --output text)
APP_VERSION=$(echo "$APP_VERSION" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+")
ECR_REPO_NAME=$(aws ssm get-parameter --name "/app/${Env}/ecr_repository_name" --query "Parameter.Value" --output text)
public_hostname=$(curl http://169.254.169.254/latest/meta-data/public-hostname)
sudo chmod 666 /var/run/docker.sock
docker pull $AccountId.dkr.ecr.$aws_region.amazonaws.com/$ECR_REPO_NAME:$APP_VERSION
docker run -t -d -p 3000:3000 --name $ECR_REPO_NAME $AccountId.dkr.ecr.$aws_region.amazonaws.com/$ECR_REPO_NAME:$APP_VERSION

yum update -y
yum install -y amazon-cloudwatch-agent
yum install -y amazon-cloudwatch-agent httpd

# Start Apache Server
systemctl start httpd
systemctl enable httpd
echo -e "Apache running on: <br>$aws_region<br>App version: $APP_VERSION<br>$instance_id<br>$public_hostname<br>Env: $Env" > /var/www/html/index.html

# Configure Apache to log in JSON format
echo 'LogFormat "{   \"LogType\": \"access\",   \"time\": \"%{%Y-%m-%dT%H:%M:%S%z}t\",   \"remote_ip\": \"%a\",   \"host\": \"%v\",   \"method\": \"%m\",   \"url\": \"%U\",   \"query\": \"%q\",   \"protocol\": \"%H\",   \"status\": \"%>s\",   \"bytes_sent\": \"%B\",   \"referer\": \"%{Referer}i\",   \"user_agent\": \"%{User-Agent}i\",   \"response_time_microseconds\": \"%D\",   \"forwarded_for\": \"%{X-Forwarded-For}i\",   \"http_version\": \"%H\",   \"request\": \"%r\" }" json' > /etc/httpd/conf.d/custom_log_format.conf
echo 'CustomLog /var/log/httpd/access_log json' >> /etc/httpd/conf.d/custom_log_format.conf
systemctl restart httpd


# Ensure Apache's access log file exists
if [ ! -f /var/log/httpd/access_log ]; then
    touch /var/log/httpd/access_log
fi


# Not working on this amaon linux image. This is for old version of CW agent
# Set the region in the CloudWatch Agent configuration file
#sed -i 's/region = .*/region = ${var.aws_region}/' /etc/awslogs/awscli.conf

# Not working on this amaon linux image
# Generate Logs Every Minute
sudo yum install -y cronie
sudo systemctl enable crond
sudo systemctl start crond
echo "* * * * * root echo '{\"LogType\": \"sample_logs\", \"message\": \"Sample log generated at $(date --iso-8601=seconds)\"} frommm AWS CloudWatch Agent' >> /var/log/sample_logs" >> /etc/cron.d/generate_logs
chmod 0644 /etc/cron.d/generate_logs


# Start CloudWatch Agent
# /var/log/message is not available in the newest version of Amazon Linux AMI, so, journalctl is used instead but the logs are not persistent
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


END_TIME=$(date +%s)
RUNNING_TIME=$((END_TIME - START_TIME))
echo "User_data procesing elapsed time: $RUNNING_TIME" 
echo "User_data procesing elapsed time: $RUNNING_TIME" > /home/ec2-user/running_time.txt
aws ssm put-parameter \
    --name "/app/${Env}/running_time_user_data" \
    --value "${RUNNING_TIME} seconds" \
    --type "String" \
    --overwrite