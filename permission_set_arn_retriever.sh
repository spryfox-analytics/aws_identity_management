#!/bin/bash

instance_arn=$(aws sso-admin list-instances --region "${2}" --max-results 1 --query "Instances[0].InstanceArn" --output text)
permission_sets_json=$(aws sso-admin list-permission-sets --region "${2}" --instance-arn "$instance_arn" --output json)
for permission_set_arn in $(echo "$permission_sets_json" | jq -r '.PermissionSets[]'); do
    permission_set_details_json=$(aws sso-admin describe-permission-set --region "${2}" --instance-arn "$instance_arn" --permission-set-arn "$permission_set_arn" --output json)
    name=$(echo "$permission_set_details_json" | jq -r '.PermissionSet.Name')
    if [ "$name" = "$1" ]; then
        echo "{\"arn\": \"${permission_set_arn}\"}"
        exit 0
    fi
done
echo "{\"arn\": \"\"}"
exit 0
