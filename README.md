# Multi-Tier AWS Deployment with Terraform

## ❓ About
Provision infrastructure for a multi-tier app on AWS using Terraform.
This project creates:


## 🧰 Tech
- Terraform
- AWS CLI

## 🚀 Getting Started

### 📝 Prerequisites
Before you begin, make sure you have the following installed:
- Terraform
- Text editor (I used VS Code)
- AWS CLI

Other requirements:
- An AWS account with a user with appropriate access and both an access key and secret access key
- A custom domain (Must be able to create an S3 bucket using the domain. Note that S3 bucket names are globally unique.)

### ⚙️ Setup / Installation
1. Clone the repo
   ```bash
    git clone https://github.com/natoriamilligan/aws-multi-tier-terraform.git
   ```
2. In the resources.tf file, find the locals block and change the root_domain, subdomain, and api_domain argument values to match your custom domain
3. Navigate to the project folder
4. Configure AWS credentials in terminal
   ```bash
   aws configure
   ```
5. Input access key and secret access key
6. Initialize Terraform
   ```bash
   terraform init
   ```
7. Review and plan
   ```bash
   terraform plan
   ```
8. Apply the infrastructure
   ```bash
   terraform apply
   ```
9. To tear down the infrastructure
   ```bash
   terraform destroy
   ```
## 🚧 Troubleshooting
