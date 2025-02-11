#!/bin/bash
awsregion=us-east-1
GIT_BRANCH=dev
if current_infra_version=$(aws ssm get-parameter --region ${aws_region} --name "/app/${GIT_BRANCH}/infrastructure_version" --query "Parameter.Value" --output text 2>/dev/null); then
    echo "current_infra_version=${current_infra_version}"
    
    exit 1
else
    echo "Parameter '/app/${GIT_BRANCH}/infrastructure_version' not found, setting current_infra_version to empty"
    current_infra_version=''
    exit 0
fi
