#!/bin/bash

# Exit on error
set -e

# Default values
ENVIRONMENT="dev"
AWS_REGION="us-east-1"
STACK_NAME="business-project-infra"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --environment|-e)
      ENVIRONMENT="$2"
      shift
      shift
      ;;
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
      echo "  --environment, -e    Environment name (default: dev)"
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

echo "Deploying Business Project infrastructure to AWS..."
echo "Environment: $ENVIRONMENT"
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

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  echo "Docker is not installed. Please install it first."
  exit 1
fi

# Deploy CloudFormation stack
echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
  --template-file ../infrastructure/cloudformation.yaml \
  --stack-name $STACK_NAME \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    EnvironmentName=$ENVIRONMENT \
  --region $AWS_REGION

# Get outputs from CloudFormation stack
echo "Getting stack outputs..."
EKS_CLUSTER_NAME=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --query "Stacks[0].Outputs[?OutputKey=='EksClusterName'].OutputValue" \
  --output text \
  --region $AWS_REGION)

ECR_REPOSITORY_URI=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --query "Stacks[0].Outputs[?OutputKey=='EcrRepositoryUri'].OutputValue" \
  --output text \
  --region $AWS_REGION)

# Configure kubectl
echo "Configuring kubectl for EKS cluster: $EKS_CLUSTER_NAME"
aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_REGION

# Build and push Docker image
echo "Building Docker image..."
docker build -t business-project:latest .

echo "Tagging and pushing Docker image to ECR: $ECR_REPOSITORY_URI"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY_URI
docker tag business-project:latest $ECR_REPOSITORY_URI:latest
docker push $ECR_REPOSITORY_URI:latest

# Generate a random password for MySQL
MYSQL_PASSWORD=$(openssl rand -base64 12)

# Create MySQL secret
echo "Creating MySQL secret..."
cat <<EOF > k8s/mysql-secret-values.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
type: Opaque
stringData:
  jdbc-url: jdbc:mysql://mysql-service:3306/businessproject
  username: root
  password: $MYSQL_PASSWORD
EOF

# Deploy Kubernetes resources
echo "Deploying Kubernetes resources..."
kubectl apply -f k8s/mysql-secret-values.yaml
kubectl apply -f k8s/mysql-pvc.yaml
kubectl apply -f k8s/mysql-deployment.yaml
kubectl apply -f k8s/mysql-service.yaml

# Replace placeholders in deployment.yaml
echo "Updating deployment.yaml with ECR repository URI..."
AWS_ACCOUNT_ID=$(echo $ECR_REPOSITORY_URI | cut -d'.' -f1)
sed -i "s|\${AWS_ACCOUNT_ID}|$AWS_ACCOUNT_ID|g" k8s/deployment.yaml
sed -i "s|\${AWS_REGION}|$AWS_REGION|g" k8s/deployment.yaml
sed -i "s|\${IMAGE_TAG}|latest|g" k8s/deployment.yaml

# Deploy application
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml

# Wait for deployment to complete
echo "Waiting for deployment to complete..."
kubectl rollout status deployment/business-project

# Get the ALB URL
echo "Getting ALB URL..."
sleep 30  # Wait for ingress to be created
ALB_URL=$(kubectl get ingress business-project-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Deployment completed successfully!"
echo "MySQL Password: $MYSQL_PASSWORD"
echo "Application URL: http://$ALB_URL"
echo "Note: It may take a few minutes for the ALB to become available."
