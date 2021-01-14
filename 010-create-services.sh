#!/bin/bash
set -e

if ibmcloud resource service-instance $COS_SERVICE_NAME > /dev/null 2>&1; then
  echo "Cloud Object Storage service $COS_SERVICE_NAME already exists"
else
  echo "Creating Cloud Object Storage Service..."
  ibmcloud resource service-instance-create $COS_SERVICE_NAME \
    cloud-object-storage "$COS_SERVICE_PLAN" global || exit 1
fi

COS_INSTANCE_CRN=$(ibmcloud resource service-instance --output JSON $COS_SERVICE_NAME | jq -r '.[0].id')
echo "Cloud Object Storage CRN is $COS_INSTANCE_CRN"

if ibmcloud resource service-key $COS_SERVICE_NAME-for-functions > /dev/null 2>&1; then
  echo "Service key already exists"
else
  ibmcloud resource service-key-create $COS_SERVICE_NAME-for-functions Writer --instance-id $COS_INSTANCE_CRN
fi

ibmcloud cos config crn --crn $COS_INSTANCE_CRN --force

echo '>>> iam authorization policy from flow-log-collector to COS bucket'
EXISTING_POLICIES=$(ibmcloud iam authorization-policies --output JSON)
if echo "$EXISTING_POLICIES" | \
  jq -e '.[] |
  select(.subjects[].attributes[].value=="flow-log-collector") |
  select(.subjects[].attributes[].value=="is") |
  select(.roles[].display_name=="Writer") |
  select(.resources[].attributes[].value=="cloud-object-storage") |
  select(.resources[].attributes[].value=="'$COS_INSTANCE_CRN'")' > /dev/null; then
  echo "Writer policy between flow-log-collector and COS bucket already exists"
else
  ibmcloud iam authorization-policy-create is cloud-object-storage \
    Writer \
    --source-resource-type flow-log-collector \
    --target-service-instance-id $COS_INSTANCE_CRN
fi

# Create the bucket
if ibmcloud cos head-bucket --bucket $COS_BUCKET_NAME --region $COS_REGION > /dev/null 2>&1; then
  echo "Bucket already exists"
else
  echo "Creating storage bucket $COS_BUCKET_NAME"
  ibmcloud cos create-bucket \
    --bucket $COS_BUCKET_NAME \
    --ibm-service-instance-id $COS_INSTANCE_CRN \
    --region $COS_REGION
fi

if ibmcloud resource service-instance $SQL_QUERY_SERVICE_NAME > /dev/null 2>&1; then
  echo "LogDNA service $SQL_QUERY_NAME already exists"
else
  echo "Creating SQL Query Service..."
  ibmcloud resource service-instance-create $SQL_QUERY_SERVICE_NAME \
    sql-query "$SQL_QUERY_SERVICE_PLAN" $SQL_QUERY_REGION || exit 1
fi
SQL_QUERY_INSTANCE_CRN=$(ibmcloud resource service-instance --output JSON $SQL_QUERY_SERVICE_NAME | jq -r .[0].id)
echo "SQL Query ID is $SQL_QUERY_INSTANCE_CRN"


