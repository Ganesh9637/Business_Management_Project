# Business Management Web Application

![home (2)](https://github.com/SuhasKamate/Business_Management_Project/assets/126138738/e8db8f17-72d6-42a0-b264-def0bf883bbf)

## Project Description: Business Management Web Application 
The Business Management Web Application is a comprehensive tool designed to help businesses manage various aspects of their operations. It provides a user-friendly interface for tasks like managing customer data, inventory, orders, and more.

## Features:

- **Customer Management**: Easily add, update, and delete customer information.
- **Inventory Management**: Keep track of your inventory items, including stock levels and pricing.
- **Order Management**: Manage customer orders such as order creation.
- **User Authentication**: Secure login and authentication for admin and staff members.
- **Role-Based Access Control**: Define roles and permissions for different user types.
- **Thymeleaf Templates**: Utilizes Thymeleaf for dynamic HTML templates.
- **Database Integration**: Integrated with MySQL for data storage.

## Technologies Used:

- Spring Boot: Backend framework for building Java-based web applications.
- Thymeleaf: Server-side Java template engine for dynamic HTML generation.
- MySQL: Relational database management system for data storage.
- Docker: Containerization of the application.
- Kubernetes: Container orchestration for deployment.
- AWS: Cloud infrastructure for hosting the application.

## Local Development Setup:

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/business-project.git
   ```

2. Import the project inside STS/Eclipse:
   - Open STS/Eclipse > file > import > maven > existing project > browse > finish.
     
3. Make sure you are in the Business_Management_Project directory.

4. Configure the database connection in application.properties:
   ```
   spring.datasource.name=businessproject
   spring.datasource.url=jdbc:mysql://localhost:3306/businessproject
   spring.datasource.password=root
   spring.datasource.username=root
   spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver
   spring.jpa.hibernate.ddl-auto=update
   server.port=2330
   ```

5. Run the project:
   - Run the main method in BusinessProjectApplication.java OR 
   - Right click on the project > Run As > Spring Boot App.

6. Open http://localhost:2330/home in any browser.

7. Now your tables will be created in the database.
   - You have to add one admin data manually to login as admin.

## AWS CI/CD and EKS Deployment

This project includes infrastructure as code and CI/CD pipeline configurations for deploying to AWS EKS.

### Prerequisites

1. AWS CLI installed and configured
2. kubectl installed
3. Docker installed
4. GitHub account (if using GitHub Actions)

### Infrastructure Deployment

1. Deploy the CloudFormation stack:
   ```
   aws cloudformation create-stack \
     --stack-name business-project-infra \
     --template-body file://infrastructure/cloudformation.yaml \
     --capabilities CAPABILITY_NAMED_IAM \
     --parameters ParameterKey=EnvironmentName,ParameterValue=dev
   ```

2. Wait for the stack to complete:
   ```
   aws cloudformation wait stack-create-complete --stack-name business-project-infra
   ```

3. Get the EKS cluster name:
   ```
   export EKS_CLUSTER_NAME=$(aws cloudformation describe-stacks --stack-name business-project-infra --query "Stacks[0].Outputs[?OutputKey=='EksClusterName'].OutputValue" --output text)
   ```

4. Configure kubectl:
   ```
   aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region us-east-1
   ```

### CI/CD Pipeline

#### Option 1: AWS CodePipeline (Automatically deployed with CloudFormation)

The CloudFormation template includes an AWS CodePipeline configuration that will automatically build and deploy your application when you push to your GitHub repository.

1. Create a GitHub personal access token with repo permissions
2. Store the token in AWS Secrets Manager:
   ```
   aws secretsmanager create-secret \
     --name GitHubToken \
     --secret-string '{"token":"your-github-token"}'
   ```

3. Update the GitHub repository URL in the CloudFormation template to point to your repository

#### Option 2: GitHub Actions

1. Add the following secrets to your GitHub repository:
   - AWS_ACCESS_KEY_ID
   - AWS_SECRET_ACCESS_KEY
   - AWS_ACCOUNT_ID

2. Push to the main branch to trigger the CI/CD pipeline

### Manual Deployment

If you want to deploy manually:

1. Build the Docker image:
   ```
   docker build -t business-project:latest .
   ```

2. Tag and push to ECR:
   ```
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
   docker tag business-project:latest $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/business-project:latest
   docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/business-project:latest
   ```

3. Deploy to Kubernetes:
   ```
   kubectl apply -f k8s/mysql-secret.yaml
   kubectl apply -f k8s/mysql-pvc.yaml
   kubectl apply -f k8s/mysql-deployment.yaml
   kubectl apply -f k8s/mysql-service.yaml
   kubectl apply -f k8s/deployment.yaml
   kubectl apply -f k8s/service.yaml
   kubectl apply -f k8s/ingress.yaml
   ```

## WorkFlow:

![workflow](https://github.com/SuhasKamate/Business_Management_Project/assets/126138738/aea72470-49c8-41a4-8974-48737638ae19)

## Preview:

### Products 
![products (2)](https://github.com/SuhasKamate/Business_Management_Project/assets/126138738/0496f63a-f30c-4108-91a7-966bd37b2b54)

### Location 
![locateus](https://github.com/SuhasKamate/Business_Management_Project/assets/126138738/30e40d74-d2f0-48cb-91b3-ea515f12c498)

### Login Page
![logins](https://github.com/SuhasKamate/Business_Management_Project/assets/126138738/9c1efb48-5b23-4a43-8c96-81d55a7b1180)

### AdminPanel
![adminpanel](https://github.com/SuhasKamate/Business_Management_Project/assets/126138738/b89aa5ee-3f7f-4145-b063-048729e7fbe9)

### UserPanel 
![userpanel](https://github.com/SuhasKamate/Business_Management_Project/assets/126138738/e0f81692-c049-4a2f-a78d-30d3906f4429)

### Exception page
![exceptionPage](https://github.com/SuhasKamate/Business_Management_Project/assets/126138738/4349a429-61ff-4ecd-a463-2900874e1ea5)