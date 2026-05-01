variable "vpc_cidr" {
    description = "CIDR block for the VPC"
    type        = string
  
}

variable "name_prefix" {
    description = "Prefix for naming resources in the VPC (e.g., 'dev', 'prod') "
    type        = string        
  
}

variable "tags" {
    description = "Tags to apply to all resources"
    type        = map(string)
    default     = {}
}

variable "public_subnets" {
    description = "List of public subnet cidr blocks"
    type        = list(string)
}

variable "private_subnets" {
    description = "List of private subnet cidr blocks"
    type        = list(string)
}

variable "azs" {
    description = "List of availability zones for subnets"
    type        = list(string)
}

variable "public_subnet_tags" {
    description = "Additional tags for public subnets"
    type        = map(string)
    default     = {}
}

variable "private_subnet_tags" {
    description = "Additional tags for private subnets"
    type        = map(string)
    default     = {}
}

variable "enable_nat_gateway" {
    description = "Whether to create a NAT Gateway for private subnets"
    type        = bool
    default     = true
}

variable "single_nat_gateway" {
    description = "Use a single NAT gateway for all the private subnets."
    type        = bool
    default     = true
}