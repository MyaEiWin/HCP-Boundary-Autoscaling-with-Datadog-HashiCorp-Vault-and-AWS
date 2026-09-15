output "target_instance_id" {
  description = "EC2 instance ID of the Boundary SSH target."
  value       = aws_instance.target.id
}

output "target_private_ip" {
  description = "Private address to use when the Boundary worker is later deployed in this VPC."
  value       = aws_instance.target.private_ip
}

output "target_public_ip" {
  description = "Temporary direct-SSH address for lab bootstrap and verification."
  value       = aws_instance.target.public_ip
}

output "target_security_group_id" {
  description = "Target security group; a future Boundary-worker security group can be allowed to reach port 22 here."
  value       = aws_security_group.target.id
}

output "vpc_id" {
  description = "Lab VPC ID for the future Boundary worker ASG."
  value       = aws_vpc.lab.id
}

output "target_subnet_id" {
  description = "Subnet ID. A separate private worker subnet will be added before worker deployment."
  value       = aws_subnet.target.id
}

