# Steps and Notes

## Steps Taken
1. Created Terraform files
   - Set locals to limit redundancy in resources.tf
3. Add nameservers from hosted zone to Domain Registrar


## What I've Learned So Far
* `create_before_destroy` is a Terraform feature that prevents downtime by creating a resource to replace another before deleting the old resource.
* For each and loops in Terraform can come together to create resources from a list
* Terraform Registry and how to search for example code blocks and additional documentation
* Reference a resource when you are creating/managing the resource, reference a data block if you are referencing an existing resource
* Learned how to find the correct steps to configure resources outside of the AWS console
