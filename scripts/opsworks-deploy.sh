#!/bin/bash
# This script uses the AWS CLI tools to initiate and monitor an OpsWorks application deployment
# Expected arguments:
## First to be aws stack id: 
## Second to be app-id
## Third to be layer-id
## Forth is the access_key_id
## Fifth is the secret_access_key

RETRY_LIMIT=60
WAIT_TIME=20s
RETRY_COUNT=0
SUCCESS=0
LAST_STATUS=""
status_re=".*\"Status\": \"(\w+)\".*"
deployid_re=".*\"DeploymentId\": \"([a-zA-Z0-9\-]+)\""


#Get instances that we need to deploy too

#Set acces keys

export AWS_ACCESS_KEY_ID=${4}
export AWS_SECRET_ACCESS_KEY=${5}

instances="$(aws opsworks --region us-east-1 describe-instances --layer-id="${3}" --query Instances[].InstanceId)"

# Initiate deployment using aws cli
DEPLOY=`aws opsworks --region=us-east-1 create-deployment --stack-id="${1}" --app-id="${2}" --instance-ids="${instances}" --command="{\"Name\":\"deploy\"}"`
# check response for deployment-id
if [[ $DEPLOY =~ $deployid_re ]]
then
  DEPLOY_ID=${BASH_REMATCH[1]}
  echo "Deployment initiated, ID: ${DEPLOY_ID}"
else
  echo "Deployment unsuccessful, response from AWS CLI: ${DEPLOY}"
  exit 1
fi

while [ $SUCCESS -ne 1 ] && [ $RETRY_COUNT -lt $RETRY_LIMIT  ]
do
  echo "Attempt #${RETRY_COUNT} of ${RETRY_LIMIT}...";
  RESULTS=`aws opsworks --region us-east-1 describe-deployments --deployment-ids ${DEPLOY_ID}`

  if [[ $RESULTS =~ $status_re ]]
  then
    LAST_STATUS=${BASH_REMATCH[1]}
    echo "Current Status: ${LAST_STATUS}";
    if [ "${LAST_STATUS}" == "successful" ]
    then
      SUCCESS=1
      break
    elif [ "${LAST_STATUS}" == "failed" ]
    then
      break
    fi
  fi

  sleep $WAIT_TIME;
  ((RETRY_COUNT++))
done

if [ $SUCCESS -eq 1 ]
then
  echo "Deployment completed successfully!"
  exit 0
else
  echo "Deployment did not complete successfully, status: ${LAST_STATUS}"
  exit 2
fi