variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

}


variable "public_subnet_1_cidr_block" {
  description = "The CIDR block for the public subnet in us-east-1a"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_2_cidr_block" {
  description = "The CIDR block for the public subnet in us-east-1b"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_1_cidr_block" {
  description = "The CIDR block for the private subnet in us-east-1a"
  type        = string
  default     = "10.0.11.0/24"
}

variable "private_subnet_2_cidr_block" {
  description = "The CIDR block for the private subnet in us-east-1b"
  type        = string
  default     = "10.0.12.0/24"
}

variable "public_security_group" {
  description = "The security group ID for the public instances"
  type        = any
  default     = "sg-0bb1c12345EXAMPLE"

}

variable "user_private_ip" {
  description = "Your private IP address with CIDR notation"
  type        = string
  default     = "73.126.54.78/32"
}

variable "db_name" {
  description = "Initial database name for RDS"
  type        = string
  default     = "students_db"
}

variable "db_master_username" {
  description = "RDS master username"
  type        = string
  default     = "admin"
}

