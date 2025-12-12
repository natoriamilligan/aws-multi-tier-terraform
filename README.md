# Multi-Tier AWS Infrastructure with Terraform

<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#-overview">Overview</a>
      <ul>
        <li><a href="#-tech">Tech</a></li>
      </ul>
    </li>
    <li>
      <a href="#-getting-started">Getting Started</a>
      <ul>
        <li><a href="#-prerequisites">Prerequisites</a></li>
        <li><a href="#%EF%B8%8F-setup--installation">Setup / Installation</a></li>
      </ul>
    </li>
    <li><a href="#-troubleshooting">Troubleshooting</a></li>
    <li><a href="#-what-i-learned">What I Learned</a></li>
    <li><a href="#-contact">Contact</a></li>
  </ol>
</details>

## ❓ Overview
Provision infrastructure for a multi-tier app on AWS using Terraform. [See Diagrams](./architecture-diagrams/)

This project creates:

1. Frontend
- S3 bucket for hosting static website 
- CloudFront distribution for global content delivery
- TLS certificate using AWS Certificate Manager for HTTPS
- Used a custom domain pointing to CloudFront

2. Backend
- Repository (ECR) for holding docker images
- ECS Fargate tasks 
- Application Load Balancer distributing traffic to ECS tasks
- Security group allowing traffic from ALB to ECS tasks
- CloudWatch log group for ECS tasks

3. Database
- Amazon RDS for PostgreSQL database
- Private subnet placement for security
- Security group allowing traffic only from ECS tasks

4. Networking
- VPC with public and private subnets
- Internet Gateway for public access
- NAT Gateway for private subnet internet access for ECS tasks to Secrets Manager

5. Other Resources
- IAM role for Terraform
- Secret in ASM for application database variables


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
- Source code for a multi tier app with PostgreSQL as the database

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
13. To check the database URI for local development
    ```bash
    terraform output db_secret_string
    ```
14. Add the hosted zone NS to the Domain Registrar used to create domain. (Note: It can take up to 48 hours for DNS propagation. You might need to stop Terraform (Ctrl + C) and rerun `terraform apply` to finish building your infrastructure)
    
## 🚧 Troubleshooting
- Originally I had created several data blocks that I thought I could reference in resource blocks but Terraform would not accept them. It preferred me to reference resources instead for ACM certificates and hosted zones so I had to delete those data blocks and revise the resource blocks to reference the direct resources.
- When I ran the terraform apply command it took an extremely long time for the certifications to be validated. I realized that I had not added the name servers to the Domain Registrar I used to create my domain. I had to stop Terraform for a while and rerun Terraform apply to finish creating the rest of my infrastructure.
- I did not set the content type for the S3 objects so my browser was downloading the index.html file. So, I added content types for each file but I also rebuilt my React app at the same time and used Terraform to upload. I had to research to find out that Terraform will not reupload objects if keys are the same. So, my website was still not working. I had to add a source_hash argument to the s3 bucket object resource block for Terraform to read the contents of the objects to check for changes and then reupload.

## 🧠 What I Learned
- create_before_destroy is a Terraform feature that prevents downtime by creating a resource to replace another before deleting the old resource
- For each and loops in Terraform can come together to create resources from a list
- Terraform Registry and how to search for example code blocks and additional documentation
- Reference a resource when you are creating/managing the resource, reference a data block if you are referencing an existing resource
- Learned how to find the correct steps to configure resources outside of the AWS console
- How to create a VPC and subnets
- Create an internet gateway and route table for public subnets
- Successfully used terraform init and terraform plan to check for errors in the code
- Terraform will not reupload S3 objects based on their key, you have to specify it to read the contents of the object to check for changes
- Terraform is idempotent meaning it keeps track of the current state of your infrastructure and will update it if changes are made
- Resources created outside of Terraform can prevent resources created with Terraform from being destroyed if those outside resources are dependencies

## 📫 Contact

Natoria Milligan - [@natoriamilligan](https://x.com/natoriamilligan) - natoriamilligan@gmail.com - [LinkedIn](https://www.linkedin.com/in/natoriamilligan)

Project Link: [https://github.com/natoriamilligan/aws-multi-tier-terraform](https://github.com/natoriamilligan/aws-multi-tier-terraform)

Banksie App Link: [https://github.com/natoriamilligan/Python-Simple-Banking-System](https://github.com/natoriamilligan/Python-Simple-Banking-System)
   
