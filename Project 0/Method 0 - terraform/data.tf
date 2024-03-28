variable "ami_lookup" {
  type = map(any)
  default = {
    amazonlinux2 = {
      most_recent = true
      owners      = ["amazon"]
      filters = [
        {
          name   = "name"
          values = ["amzn2-ami-hvm-*-x86_64-gp2"]
        },
        {
          name   = "virtualization-type"
          values = ["hvm"]
        }
      ]
    }
    ubuntu = {
      most_recent = true
      filters = [
        {
          name   = "name"
          values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
        },
        {
          name   = "virtualization-type"
          values = ["hvm"]
        }
      ]
      owners = ["099720109477"]
    }
  }
}

data "aws_ami" "lookup" {
  for_each    = var.ami_lookup
  most_recent = each.value.most_recent
  owners      = each.value.owners
  dynamic "filter" {
    for_each = each.value.filters
    content {
      name   = filter.value.name
      values = filter.value.values
    }
  }
}