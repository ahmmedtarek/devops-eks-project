# End-to-End DevOps CI/CD Platform on AWS

![AWS](https://img.shields.io/badge/AWS-Cloud-orange)
![Terraform](https://img.shields.io/badge/Infrastructure-Terraform-7B42BC)
![Jenkins](https://img.shields.io/badge/CI-Jenkins-D24939)
![Docker](https://img.shields.io/badge/Container-Docker-2496ED)
![Python](https://img.shields.io/badge/Application-Python-3776AB)
![License](https://img.shields.io/badge/License-MIT-green)

## Overview

This repository contains the application source code, automated tests, CI/CD pipeline, and Terraform infrastructure code for a production-style DevOps project running on AWS.

The project demonstrates how to build, test, analyze, secure, containerize, and publish a Python Flask application using a Jenkins-based CI pipeline. After a successful build, Jenkins updates a separate GitOps repository, where Argo CD takes responsibility for deploying the new version to Amazon EKS.

The architecture intentionally separates **Continuous Integration** from **GitOps-based Continuous Delivery**.

## Architecture

```text
Developer
   |
   | git push
   v
GitHub Application Repository
   |
   | GitHub Webhook
   v
Jenkins CI Pipeline
   |
   +--> Checkout
   +--> Pytest
   +--> SonarQube Analysis
   +--> Quality Gate
   +--> Docker Build
   +--> Trivy Image Scan
   +--> Push Image to Amazon ECR
   |
   | Update image tag
   v
GitHub GitOps Repository
   |
   v
Argo CD
   |
   v
Amazon EKS
   |
   v
Kubernetes Deployment
   |
   v
Running Flask Application
```

## Repository Responsibilities

This is the **application and CI repository**.

It contains:

- Flask application source code
- Unit tests
- Dockerfile
- Jenkins pipeline definition
- Terraform infrastructure code

The Kubernetes manifests are stored in a separate repository:

[GitOps Repository](https://github.com/ahmmedtarek/devops-eks-gitops)

## Project Structure

```text
.
├── app/
│   ├── app.py
│   └── __init__.py
├── test/
│   └── test_app.py
├── Dockerfile
├── Jenkinsfile
└── Terraform/
    ├── main.tf
    ├── providers.tf
    ├── variables.tf
    ├── outputs.tf
    └── terraform.tfvars
```

## Application

The application is a lightweight Python Flask web application.

The application code is located in:

```text
app/app.py
```

The automated tests are located in:

```text
test/test_app.py
```

## CI Pipeline

The Jenkins pipeline is defined in:

```text
Jenkinsfile
```

### Pipeline stages

#### 1. Checkout

Jenkins checks out the latest source code from this repository.

#### 2. Automated Testing

The pipeline runs:

```bash
python3 -m pytest
```

This validates the application before creating a container image.

#### 3. SonarQube Analysis

SonarQube analyzes the application source code for code-quality issues.

Configured project key:

```text
devops-eks-project
```

Analyzed source directory:

```text
app
```

#### 4. Quality Gate

Jenkins waits for the SonarQube Quality Gate result.

The pipeline is configured to stop when the Quality Gate fails.

#### 5. Docker Build

Jenkins builds the application image using the Dockerfile.

Example local image:

```text
app:${BUILD_NUMBER}
```

#### 6. Trivy Security Scan

Trivy scans the container image for known vulnerabilities.

This adds a DevSecOps security check before the image is published.

#### 7. Amazon ECR Push

After the required checks pass, Jenkins pushes the image to Amazon Elastic Container Registry.

Example:

```text
305018987435.dkr.ecr.eu-north-1.amazonaws.com/app:${BUILD_NUMBER}
```

The Jenkins build number is used as the image tag.

#### 8. GitOps Repository Update

Jenkins updates the Kubernetes image reference in the separate GitOps repository.

For example:

```yaml
image: 305018987435.dkr.ecr.eu-north-1.amazonaws.com/app:8
```

Jenkins then commits and pushes the change to the GitOps repository.

Jenkins does **not** directly run `kubectl apply` against EKS.

## GitHub Webhook

The GitHub webhook is configured on this application repository only.

```text
Application Repository
        |
        | push event
        v
GitHub Webhook
        |
        v
Jenkins
```

The GitOps repository does not trigger Jenkins. This prevents a webhook loop because Jenkins itself pushes the updated image tag to the GitOps repository.

## AWS Infrastructure

The infrastructure is managed using Terraform.

### AWS Region

```text
eu-north-1
```

### VPC

```text
CIDR: 10.0.0.0/16
```

### Networking

The infrastructure includes:

- One VPC
- Two public subnets
- Two private subnets
- Internet Gateway
- NAT Gateway
- Elastic IP
- Public and private route tables

The private subnet layer provides outbound internet access through the NAT Gateway without placing private resources directly on a public route.

### Jenkins EC2

Jenkins runs on an EC2 instance located in a private subnet.

Jenkins is used for:

- Source checkout
- Testing
- Code quality analysis
- Container image building
- Security scanning
- ECR publishing
- GitOps repository updates

### IAM

IAM permissions are configured to allow the required AWS operations.

In particular, Jenkins has the permissions needed to authenticate with Amazon ECR and push images.

### Amazon ECR

The Docker image registry is:

```text
Amazon Elastic Container Registry
```

Repository:

```text
app
```

Example image:

```text
305018987435.dkr.ecr.eu-north-1.amazonaws.com/app:8
```

### Amazon EKS

The Kubernetes cluster is:

```text
devops-eks-cluster
```

Region:

```text
eu-north-1
```

Argo CD deploys the Kubernetes resources into this cluster.

## Infrastructure as Code

Terraform is used to provision and manage the AWS infrastructure.

The Terraform configuration is located in:

```text
Terraform/
```

Main responsibilities include:

- VPC creation
- Public and private subnet creation
- Internet Gateway
- NAT Gateway
- Elastic IP
- Route tables
- Jenkins EC2 infrastructure
- IAM-related resources
- EKS infrastructure
- ECR-related infrastructure

## Prerequisites

Before running the project, install or configure:

- Python 3
- Docker
- Git
- Terraform
- AWS CLI
- AWS account
- Jenkins
- SonarQube
- Trivy
- Access to the target AWS account

## Run the Application Locally

Install dependencies according to the application requirements used in the project, then run the Flask application.

Example:

```bash
python3 app/app.py
```

The application listens on the port configured in the Flask application.

## Run Tests Locally

```bash
python3 -m pytest
```

## Build the Docker Image

```bash
docker build -t app:local .
```

Run the container:

```bash
docker run --rm -p 5000:5000 app:local
```

## Terraform Workflow

Initialize Terraform:

```bash
cd Terraform
terraform init
```

Review the execution plan:

```bash
terraform plan
```

Apply the infrastructure:

```bash
terraform apply
```

Review outputs:

```bash
terraform output
```

> Never commit sensitive credentials, private keys, or unprotected Terraform state files to a public repository.

## Security Practices Demonstrated

- Automated unit testing
- SonarQube code-quality analysis
- Quality Gate enforcement
- Trivy container vulnerability scanning
- IAM-based AWS permissions
- Private-subnet Jenkins placement
- Private Amazon ECR image registry
- Jenkins Credentials for GitHub authentication
- Separation of application and GitOps repositories

## Key DevOps Concepts

This project demonstrates:

- Infrastructure as Code
- Continuous Integration
- Automated testing
- Static code analysis
- Quality gates
- Containerization
- Container security scanning
- Image registries
- GitHub webhooks
- GitOps
- Kubernetes deployments
- Amazon EKS
- Argo CD reconciliation
- CI/CD repository separation

## Related Repository

Kubernetes manifests and Argo CD deployment configuration:

[https://github.com/ahmmedtarek/devops-eks-gitops](https://github.com/ahmmedtarek/devops-eks-gitops)

## Future Improvements

Possible future enhancements include:

- Helm-based Kubernetes packaging
- Prometheus and Grafana monitoring
- Argo CD notifications
- Automated rollback strategies
- Image signing
- Policy enforcement
- Centralized logging
- Pull-request based GitOps promotion
- Multi-environment deployment

## Author

**Ahmed Tarek**

GitHub: [ahmmedtarek](https://github.com/ahmmedtarek)
