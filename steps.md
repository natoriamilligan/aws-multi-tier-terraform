1. Created Terraform files
   - Set locals to limit redundancy in resources.tf
3. Add nameservers from hosted zone to Domain Registrar


# What I Learned
* `create_before_destroy` is a Terraform feature that prevents downtime by creating a resource to replace another before deleting the old resource.
