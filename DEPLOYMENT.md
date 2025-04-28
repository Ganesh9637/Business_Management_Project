# AWS CI/CD and EKS Deployment Guide

This document provides an overview of the CI/CD pipeline and EKS deployment setup for the Business Management Web Application.

## Architecture Overview

The deployment architecture consists of the following components:

1. **AWS EKS (Elastic Kubernetes Service)**: Managed Kubernetes service for running containerized applications
2. **AWS ECR (Elastic Container Registry)**: Docker container registry for storing application images
3. **AWS CodePipeline/GitHub Actions**: CI/CD pipeline for automated building and deployment
4. **AWS CloudFormation**: Infrastructure as Code for provisioning AWS resources
5. **MySQL Database**: Deployed as a containerized service within the EKS cluster

## Infrastructure Components

### VPC and Networking
- VPC with public and private subnets across two availability zones
- Internet Gateway for public internet access
- NAT Gateways for private subnet internet access
- Route tables and security groups

### EKS Cluster
- EKS control plane with public and private endpoint access
- Managed node group with auto-scaling capabilities
- IAM roles and policies for EKS and node group

### CI/CD Pipeline
- ECR repository for storing Docker images
- CodeBuild project for building and testing the application
- CodePipeline for orchestrating the CI/CD workflow
- GitHub Actions as an alternative CI/CD option

## Deployment Options

### Option 1: AWS CloudFormation

The CloudFormation template (`infrastructure/cloudformation.yaml`) provisions all the necessary AWS resources for the application deployment. To deploy using CloudFormation:

1. Deploy the CloudFormation stack:
   ```
   aws cloudformation create-stack \
     --stack-name business-project-infra \
     --template-body file://infrastructure/cloudformation.yaml \
     --capabilities CAPABILITY_NAMED_IAM \
     --parameters ParameterKey=EnvironmentName,ParameterValue=dev
   ```

2. Once the stack is created, the CI/CD pipeline will automatically build and deploy the application when code is pushed to the repository.

### Option 2: GitHub Actions

The GitHub Actions workflow (`.github/workflows/ci-cd.yml`) provides an alternative CI/CD pipeline. To use GitHub Actions:

1. Add the following secrets to your GitHub repository:
   - AWS_ACCESS_KEY_ID
   - AWS_SECRET_ACCESS_KEY
   - AWS_ACCOUNT_ID

2. Push code to the main branch to trigger the CI/CD pipeline.

### Option 3: Manual Deployment

For manual deployment, use the provided deployment script:

```
./scripts/deploy.sh
```

The script will:
1. Deploy the CloudFormation stack
2. Build and push the Docker image to ECR
3. Deploy the application to EKS

## Kubernetes Resources

The application is deployed to EKS using the following Kubernetes resources:

1. **Deployment**: Manages the application pods
   - File: `k8s/deployment.yaml`
   - Replicas: 2
   - Container image from ECR

2. **Service**: Exposes the application within the cluster
   - File: `k8s/service.yaml`
   - Type: ClusterIP
   - Port: 80 -> 2330

3. **Ingress**: Exposes the application to the internet
   - File: `k8s/ingress.yaml`
   - Type: ALB (AWS Load Balancer)
   - Path: /

4. **MySQL Deployment**: Deploys MySQL database
   - File: `k8s/mysql-deployment.yaml`
   - Persistent volume for data storage

5. **MySQL Service**: Exposes MySQL within the cluster
   - File: `k8s/mysql-service.yaml`
   - Port: 3306

6. **Secret**: Stores database credentials
   - File: `k8s/mysql-secret.yaml`

## Monitoring and Maintenance

### Monitoring
- EKS cluster metrics are available in CloudWatch
- Application logs are sent to CloudWatch Logs
- Consider implementing Prometheus and Grafana for more detailed monitoring

### Scaling
- The EKS node group is configured with auto-scaling
- The application deployment can be scaled by adjusting the replica count

### Backup and Disaster Recovery
- MySQL data is stored on persistent volumes
- Consider implementing regular database backups
- Use ECR lifecycle policies to manage container images

## Security Considerations

1. **Network Security**:
   - Private subnets for application workloads
   - Security groups restricting access

2. **Authentication and Authorization**:
   - IAM roles for service accounts
   - RBAC for Kubernetes access control

3. **Secrets Management**:
   - Kubernetes secrets for sensitive information
   - Consider using AWS Secrets Manager for production

4. **Container Security**:
   - ECR image scanning enabled
   - Non-root user in container

## Cost Optimization

1. **EKS Cluster**:
   - Use appropriate instance types for node groups
   - Implement auto-scaling to match demand

2. **NAT Gateways**:
   - Consider using a single NAT Gateway for dev environments

3. **ECR**:
   - Implement lifecycle policies to remove unused images

## Troubleshooting

### Common Issues

1. **Deployment Failures**:
   - Check CodeBuild/GitHub Actions logs
   - Verify ECR image exists and is accessible
   - Check Kubernetes events: `kubectl get events`

2. **Application Not Accessible**:
   - Verify ingress controller is running
   - Check ALB configuration
   - Verify security group settings

3. **Database Connection Issues**:
   - Verify MySQL pod is running
   - Check secret values
   - Verify service discovery is working

### Useful Commands

```bash
# Get EKS cluster info
aws eks describe-cluster --name business-project-cluster

# Get Kubernetes resources
kubectl get pods,svc,ingress

# Check application logs
kubectl logs deployment/business-project

# Check MySQL logs
kubectl logs deployment/mysql

# Port forward to test locally
kubectl port-forward svc/business-project 8080:80
```

## Conclusion

This deployment setup provides a scalable, reliable, and secure infrastructure for the Business Management Web Application. The CI/CD pipeline ensures that code changes are automatically built, tested, and deployed, reducing manual effort and potential errors.