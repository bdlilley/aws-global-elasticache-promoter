#!/bin/bash

NAME="aws-global-elasticache-promoter"

aws_identity=$(aws sts get-caller-identity)
if [ "$?" -ne "0" ]; then
  echo "failed to execute \"aws sts get-caller-identity\"; please make sure your aws cli environment is set up"
  exit -1
fi
accountId=$(echo $aws_identity | jq -r ".Account")

rm -rf .build
mkdir -p .build

set -euo pipefail

GOOS=linux GOARCH=amd64 go build -o .build/main

zip .build/lambda.zip .build/main

set +euo pipefail

aws iam create-role --region us-east-1 --role-name "${NAME}-us-east-1" --tags "Key=created-by,Value=benji_lilley" "Key=team,Value=product" "Key=purpose,Value=product-development" --assume-role-policy-document '{"Version": "2012-10-17","Statement": [{ "Effect": "Allow", "Principal": {"Service": "lambda.amazonaws.com"}, "Action": "sts:AssumeRole"}]}' || true
# aws iam create-policy --policy-name "${NAME}" --tags "Key=created-by,Value=benji_lilley" "Key=team,Value=product" "Key=purpose,Value=product-development" --policy-document '{"Version": "2012-10-17","Statement": [{"Sid": "VisualEditor0","Effect": "Allow","Action": ["eks:DescribeNodegroup","eks:ListNodegroups","eks:UpdateNodegroupConfig","eks:DescribeCluster"],"Resource": ["arn:aws:eks:*:931713665590:cluster/*","arn:aws:eks:*:931713665590:nodegroup/*/*/*"]},{"Sid": "VisualEditor1","Effect": "Allow","Action": ["ec2:describeRegions","sts:getCallerIdentity","eks:ListClusters"],"Resource": "*"}]}'
aws iam attach-role-policy --region us-east-1 --role-name "${NAME}-us-east-1" --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole || true
# aws iam attach-role-policy --role-name "${NAME}" --policy-arn "arn:aws:iam::931713665590:policy/${NAME}" || true

aws lambda create-function \
    --function-name "${NAME}" \
    --runtime go1.x \
    --zip-file "fileb://.build/lambda.zip" \
    --handler ".build/main" \
    --role "arn:aws:iam::${accountId}:role/${NAME}-us-east-1" \
    --tags "created-by=benji_lilley,team=product,purpose=product-development" \
    --timeout 300 \
    --region us-east-1 \
    || true

aws lambda update-function-code \
    --function-name "${NAME}" \
    --region us-east-1 \
    --zip-file "fileb://.build/lambda.zip"

aws lambda update-function-configuration \
    --function-name "${NAME}" \
    --environment "Variables={BUCKET=my-bucket,KEY=file.txt}"

# I set this up manually in the console
# aws events put-rule --name "$NAME" --schedule-expression "cron(0 1 * * ? *)" || true
# aws events put-targets --rule "$NAME" --targets "Id"="1","Arn"="arn:aws:lambda:us-east-2:931713665590:function:${NAME}","RoleArn"="" || true
