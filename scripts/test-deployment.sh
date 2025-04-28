#!/bin/bash

# Exit on error
set -e

# Default values
AWS_REGION="us-east-1"
STACK_NAME="business-project-infra"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --region|-r)
      AWS_REGION="$2"
      shift
      shift
      ;;
    --stack-name|-s)
      STACK_NAME="$2"
      shift
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --region, -r         AWS region (default: us-east-1)"
      echo "  --stack-name, -s     CloudFormation stack name (default: business-project-infra)"
      echo "  --help, -h           Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "Testing Business Project deployment..."
echo "AWS Region: $AWS_REGION"
echo "Stack Name: $STACK_NAME"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
  echo "AWS CLI is not installed. Please install it first."
  exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
  echo "kubectl is not installed. Please install it first."
  exit 1
fi

# Check if curl is installed
if ! command -v curl &> /dev/null; then
  echo "curl is not installed. Please install it first."
  exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo "jq is not installed. Please install it first."
  exit 1
fi

# Check CloudFormation stack status
echo "Checking CloudFormation stack status..."
STACK_STATUS=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --query "Stacks[0].StackStatus" \
  --output text \
  --region $AWS_REGION)

if [[ "$STACK_STATUS" != "CREATE_COMPLETE" && "$STACK_STATUS" != "UPDATE_COMPLETE" ]]; then
  echo "CloudFormation stack is not in a complete state. Current status: $STACK_STATUS"
  exit 1
fi

echo "CloudFormation stack status: $STACK_STATUS"

# Get EKS cluster name
echo "Getting EKS cluster name..."
EKS_CLUSTER_NAME=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --query "Stacks[0].Outputs[?OutputKey=='EksClusterName'].OutputValue" \
  --output text \
  --region $AWS_REGION)

if [[ -z "$EKS_CLUSTER_NAME" ]]; then
  echo "Failed to get EKS cluster name from CloudFormation outputs."
  exit 1
fi

echo "EKS cluster name: $EKS_CLUSTER_NAME"

# Check EKS cluster status
echo "Checking EKS cluster status..."
CLUSTER_STATUS=$(aws eks describe-cluster \
  --name $EKS_CLUSTER_NAME \
  --query "cluster.status" \
  --output text \
  --region $AWS_REGION)

if [[ "$CLUSTER_STATUS" != "ACTIVE" ]]; then
  echo "EKS cluster is not active. Current status: $CLUSTER_STATUS"
  exit 1
fi

echo "EKS cluster status: $CLUSTER_STATUS"

# Configure kubectl
echo "Configuring kubectl..."
aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_REGION

# Check node status
echo "Checking node status..."
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
if [[ $NODE_COUNT -lt 1 ]]; then
  echo "No nodes found in the EKS cluster."
  exit 1
fi

READY_NODES=$(kubectl get nodes --no-headers | grep -c "Ready")
if [[ $READY_NODES -lt 1 ]]; then
  echo "No nodes are in Ready state."
  exit 1
fi

echo "Node count: $NODE_COUNT, Ready nodes: $READY_NODES"

# Check pod status
echo "Checking pod status..."
RUNNING_PODS=$(kubectl get pods --all-namespaces --field-selector=status.phase=Running --no-headers | wc -l)
if [[ $RUNNING_PODS -lt 1 ]]; then
  echo "No pods are running in the cluster."
  exit 1
fi

echo "Running pods: $RUNNING_PODS"

# Check business-project deployment
echo "Checking business-project deployment..."
if ! kubectl get deployment business-project &> /dev/null; then
  echo "business-project deployment not found."
  exit 1
fi

REPLICAS=$(kubectl get deployment business-project -o jsonpath='{.status.replicas}')
READY_REPLICAS=$(kubectl get deployment business-project -o jsonpath='{.status.readyReplicas}')

if [[ -z "$READY_REPLICAS" || "$READY_REPLICAS" -lt "$REPLICAS" ]]; then
  echo "Not all replicas are ready. Ready: $READY_REPLICAS, Total: $REPLICAS"
  exit 1
fi

echo "Deployment status: $READY_REPLICAS/$REPLICAS replicas ready"

# Check service
echo "Checking business-project service..."
if ! kubectl get service business-project &> /dev/null; then
  echo "business-project service not found."
  exit 1
fi

# Check ingress
echo "Checking business-project ingress..."
if ! kubectl get ingress business-project-ingress &> /dev/null; then
  echo "business-project-ingress not found."
  exit 1
fi

ALB_URL=$(kubectl get ingress business-project-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
if [[ -z "$ALB_URL" ]]; then
  echo "ALB URL not found in ingress."
  exit 1
fi

echo "ALB URL: $ALB_URL"

# Test application endpoint
echo "Testing application endpoint..."
echo "Note: This may take a few minutes for the ALB to become available."
echo "Waiting for ALB to be ready..."

MAX_RETRIES=10
RETRY_COUNT=0
HTTP_STATUS=0

while [[ $RETRY_COUNT -lt $MAX_RETRIES && $HTTP_STATUS -ne 200 ]]; do
  echo "Attempt $((RETRY_COUNT+1))/$MAX_RETRIES..."
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$ALB_URL/home || echo 0)
  if [[ $HTTP_STATUS -eq 200 ]]; then
    break
  fi
  RETRY_COUNT=$((RETRY_COUNT+1))
  sleep 30
done

if [[ $HTTP_STATUS -ne 200 ]]; then
  echo "Failed to get a 200 response from the application. Last status: $HTTP_STATUS"
  exit 1
fi

echo "Application is responding with HTTP status: $HTTP_STATUS"

# Check MySQL connection
echo "Checking MySQL connection from the application..."
POD_NAME=$(kubectl get pods -l app=business-project -o jsonpath='{.items[0].metadata.name}')
if [[ -z "$POD_NAME" ]]; then
  echo "Failed to get business-project pod name."
  exit 1
fi

echo "Testing database connection from pod $POD_NAME..."
DB_CONNECTION_TEST=$(kubectl exec $POD_NAME -- curl -s http://localhost:2330/actuator/health || echo '{"status":"DOWN"}')
DB_STATUS=$(echo $DB_CONNECTION_TEST | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

if [[ "$DB_STATUS" != "UP" ]]; then
  echo "Database connection test failed. Status: $DB_STATUS"
  exit 1
fi

echo "Database connection test passed. Status: $DB_STATUS"

echo "All tests passed! The deployment is working correctly."