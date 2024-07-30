output "lb_dns_name" {
  description = "The DNS name of the ELB"
  value       = module.elb.lb_dns_name
}

output "vpc_id" {
  description = "The VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnets_ids" {
  description = "The IDs of the public subnets"
  value       = module.vpc.public_subnets_ids
}

output "ssm_parameter" {
  description = "The IDs of the private subnets"
  value       = module.ssm_parameters
}
