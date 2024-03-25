##################################
#          NETWORKING            #
##################################
# VPCs
resource "aws_vpc" "networks" {
  for_each             = var.project.networking.vpcs
  cidr_block           = try(each.value.cidr_block, true)
  instance_tenancy     = try(each.value.instance_tenancy, true)
  enable_dns_support   = try(each.value.enable_dns_support, true)
  enable_dns_hostnames = try(each.value.enable_dns_hostnames, true)
  tags                 = try(each.value.tags, var.project.tags)
}

# SUBNETs
resource "aws_subnet" "subnets" {
  for_each = merge([
    for vpcKey, vpc in var.project.networking.vpcs : {
      for subnetKey, sValue in vpc.subnets :
      "${vpcKey}-${subnetKey}" => {
        id                = "${vpcKey}-${subnetKey}"
        vpc_id            = aws_vpc.networks[vpcKey].id
        cidr_block        = sValue.cidr_block
        availability_zone = try(sValue.availability_zone, "us-east-1a") #us-east-1a, us-east-1b, us-east-1c, us-east-1d, us-east-1e, us-east-1f
      }
    }
  ]...)
  vpc_id = each.value.vpc_id

  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone
  tags              = try(each.value.tags, var.project.tags)
}

# Route Tables
resource "aws_route_table" "route_tables" {
  for_each = var.project.networking.route_tables
  vpc_id   = aws_vpc.networks[each.value.parent_vpc_key].id
  dynamic "route" {
    for_each = each.value.routes
    content {
      cidr_block = route.value.cidr_block
      gateway_id = route.value.next_hop == "igw" ? aws_internet_gateway.igws[each.value.parent_vpc_key].id : null
    }
  }
  tags = try(each.value.tags, var.project.tags)

}

# Route Table Associations
resource "aws_route_table_association" "route_table_associations" {
  for_each = merge([
    for vpcKey, vpc in var.project.networking.vpcs : {
      for subnetKey, subnets in vpc.subnets :
      "${vpcKey}-${subnetKey}" => {
        route_table_key = "${subnets.route_table_key}"
      }
    }
  ]...)
  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.route_tables[each.value.route_table_key].id
}

# Internet Gateway
resource "aws_internet_gateway" "igws" {
  for_each = var.project.networking.internet_gateways
  vpc_id   = aws_vpc.networks[each.value.parent_vpc_key].id

  tags = try(each.value.tags, var.project.tags)
}


# Security Group
resource "aws_security_group" "sg" {
  for_each    = var.project.networking.security_groups
  vpc_id      = aws_vpc.networks[each.value.vpc_key].id
  name        = each.value.name
  description = try(each.value.description, "Managed by Terraform")
  ## SGs need an EGRESS and INGRESS RULE SET
  dynamic "ingress" {
    for_each = try(each.value.ingress_rules, [])
    content {
      description = ingress.value.name
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.source_cidr
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
    }
  }
  dynamic "egress" {
    for_each = try(each.value.egress_rules, [])
    content {
      description = egress.value.name
      protocol    = egress.value.protocol
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      cidr_blocks = egress.value.destination_cidr
    }
  }
  tags = try(each.value.tags, var.project.tags)
}


# Elastic File-System
resource "aws_efs_file_system" "efs" {
  for_each         = var.project.storage.efs
  encrypted        = try(each.value.encrypted, null)
  performance_mode = try(each.value.performance_mode, null)
  throughput_mode  = try(each.value.throughput_mode, null)
  lifecycle_policy {
    transition_to_ia = try(each.value.lifecycle_policy.transition_to_ia, null)
  }
  tags = try(each.value.tags, null)
}

# Attach the disk to the EC2 instance
resource "aws_efs_mount_target" "attach" {
  for_each        = { for key, value in var.project.compute.ec2 : key => value if can(value.efs_key) }
  file_system_id  = aws_efs_file_system.efs[each.value.efs_key].id
  subnet_id       = aws_subnet.subnets["${each.value.vpc_key}-${each.value.subnet_key}"].id
  security_groups = try([aws_subnet.subnets[each.value.security_group_key].id], null)
  depends_on      = [ aws_efs_file_system.efs, aws_instance.ec2 ] #instance was built in the wrong subnet, caused a conflict without these dependancies
}


# mount the file-system to the attached disk for a given local path
resource "null_resource" "efs_mount" {
  for_each = { for key, value in var.project.compute.ec2 : key => value if can(value.efs_key) }
  connection {
    type        = "ssh"
    user        = "ubuntu" #"ec2-user"
    host        = aws_eip.eip[each.key].public_ip
    private_key = tls_private_key.rsa[each.value.key_pair_key].private_key_openssh
    timeout     = "30s"
  }
  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "cat <<EOF > efs_setup.sh",
      "#!/bin/bash",
      "# Install nfs-common",
      "sudo apt-get -y install nfs-common",
      "# Mount EFS File System and Set Permissions",
      "sudo mkdir -p ${var.project.storage.efs[each.value.efs_key].tags.mount_point}",
      "sudo grep -q \"${aws_efs_file_system.efs[each.value.efs_key].dns_name}\" /etc/fstab || (printf \"\\n${aws_efs_file_system.efs[each.value.efs_key].dns_name}:/ ${var.project.storage.efs[each.value.efs_key].tags.mount_point} nfs nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0\\n\" | sudo tee -a /etc/fstab || printf \"\\n${aws_efs_file_system.efs[each.value.efs_key].dns_name}:/ ${var.project.storage.efs[each.value.efs_key].tags.mount_point} nfs nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0\\n\" | sudo tee -a /etc/fstab)",
      "sudo chown -R ${var.project.storage.efs[each.value.efs_key].tags.owner}:${var.project.storage.efs[each.value.efs_key].tags.group} ${var.project.storage.efs[each.value.efs_key].tags.mount_point}",
      "EOF",
      "chmod +x efs_setup.sh",
      "./efs_setup.sh"
    ]
  }
  depends_on = [ aws_efs_mount_target.attach ]
}
# Manage sym-link creation
resource "null_resource" "symlinks" {
  for_each = { for key, value in var.project.compute.ec2 : key => value if can(value.efs_key) }
  connection {
    type        = "ssh"
    user        = "ubuntu" #"ec2-user"
    host        = aws_eip.eip[each.key].public_ip
    private_key = tls_private_key.rsa[each.value.key_pair_key].private_key_openssh
    timeout     = "30s"
  }
  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "cat <<EOF > symlinks.sh",
      "#!/bin/bash",
      "# Create symbolic link",
      "mkdir -p ${var.project.storage.efs[each.value.efs_key].tags.mount_point}/wp-includes",
      "mkdir -p ${var.project.storage.efs[each.value.efs_key].tags.mount_point}/wp-content",
      "sudo ln -sf ${var.project.storage.efs[each.value.efs_key].tags.mount_point}/wp-includes ${var.project.storage.efs[each.value.efs_key].tags.symbolic_link}/wp-includes",
      "sudo ln -sf ${var.project.storage.efs[each.value.efs_key].tags.mount_point}/wp-content ${var.project.storage.efs[each.value.efs_key].tags.symbolic_link}/wp-content",
      "sudo chown -R ${var.project.storage.efs[each.value.efs_key].tags.owner}:${var.project.storage.efs[each.value.efs_key].tags.group} ${var.project.storage.efs[each.value.efs_key].tags.symbolic_link}",
      "EOF",
      "chmod +x symlinks.sh",
      "./symlinks.sh"
    ]
  }
  depends_on = [ null_resource.efs_mount ]
}

# Elastic IPs
resource "aws_eip" "eip" {
  for_each = var.project.networking.elastic_ip_addresses
  # attach to ec2 instance, if the ec2_instance_key attribute is set
  instance   = try(each.value.ec2_instance_key, null) != null ? aws_instance.ec2[each.value.ec2_instance_key].id : null
  depends_on = [aws_instance.ec2, aws_internet_gateway.igws]
}


# Create a nat gateway for each subnet/availability-zone
# resource "aws_nat_gateway" "frontend" {
#   for_each = merge([
#     for vpcKey, vpc in var.project.networking.vpcs : {
#       for subnetKey, subnets in vpc.subnets :
#       "${vpcKey}-${subnetKey}" => {
#         route_table_key = "${subnets.route_table_key}"
#         eip_key         = try(subnets.eip_key, null)
#       }
#       if try(subnets.eip_key, null) != null
#     }
#   ]...)
#   allocation_id     = aws_eip.eip[each.value.eip_key].id
#   subnet_id         = aws_subnet.subnets[each.key].id
#   connectivity_type = "public"  # subnets are frontend, with private-ip-ranges, advertising a route to the internet is necessary.
#   tags = { Name = "${format("ngw%d", each.value.route_table_key)}" }
#   depends_on        = [aws_eip.eip, aws_subnet.subnets]
# }

# # Load Balancer
# resource "aws_lb" "this" {
#   for_each = var.project.networking.load_balancers
#   name     = each.value.name
#   subnets = [
#     for subnet_key in each.value.subnet_keys : aws_subnet.subnets["${each.key}-${subnet_key}"].id
#   ]
#   security_groups = [
#     for security_group_key in each.value.security_group_keys : aws_security_group.sg["${each.value.security_group_key}"].id
#   ]
#   internal     = try(each.value.public_facing, true) == true ? false : true
#   idle_timeout = try(each.value.idle_timeout, 60)

#   subnet_mapping {
#     subnet_id     = aws_subnet.subnets[0].id
#     allocation_id = aws_eip.eip[2].id
#   }
#   subnet_mapping {
#     subnet_id     = aws_subnet.subnets[1].id
#     allocation_id = aws_eip.eip[3].id
#   }

# }
# resource "aws_lb_target_group" "backend" {
#   for_each = {
#     for lb_key, lb in var.project.networking.load_balancers : "${lb.name}-target-group-${lb_key}" => lb.targets
#   }
#   vpc_id   = aws_vpc.networks[0].id
#   name     = each.key
#   port     = lower(each.value[0].protocol) == "http" ? 80 : 443
#   protocol = upper(each.value[0].protocol)
#   dynamic "stickiness" {
#     for_each = each.value[0].persistence != null ? [each.value[0].persistence] : []
#     content {
#       type            = "lb_cookie"
#       cookie_duration = stickiness.value.duration
#       enabled         = stickiness.value.sticky
#     }
#   }
#   dynamic "health_check" {
#     for_each = each.value[0].health_checks != null ? [each.value[0].health_checks] : []
#     content {
#       healthy_threshold   = health_check.value.healthy_threshold
#       unhealthy_threshold = health_check.value.unhealthy_threshold
#       timeout             = health_check.value.timeout
#       interval            = health_check.value.interval
#       path                = health_check.value.path
#       port                = health_check.value.port
#     }
#   }
# }


# resource "aws_lb_listener" "frontend" {
#   for_each          = {
#     for lb_key, lb in var.project.networking.load_balancers : "${lb.name}-listener-${lb_key}" => lb.listeners
#   }
#   load_balancer_arn = aws_lb.this["${each.value.lb_key}"].arn
#   port              = lower(each.value.protocol) == "http" ? 80 : 443
#   protocol          = lower(each.value.protocol)

#   default_action {
#     target_group_arn = aws_lb_target_group.backend[each.value.backend_key].arn
#     type             = "forward"
#   }
# }
# resource "aws_lb_listener_rule" "listener_rule" {
#   for_each = var.project.networking.load_balancers.*.rules
#   listener_arn = aws_lb_listener.frontend[each.value.frontend_key].arn
#   priority     = each.value.priority
#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.backend[each.value.backend_key].id
#   }
#   condition {
#     http_header {
#       http_header_name = "X-Forwarded-For"
#       values           = ["*.*.*.*"]
#     }
#   }
# }

# DNS Zone
resource "aws_route53_zone" "public" {
  for_each = var.project.domains
  name     = each.value.name
}

# # DNS records: A
# resource "aws_route53_record" "a" {
#   zone_id = aws_route53_zone.public[0].zone_id #only interested in registering with zone 0
#   name    = aws_route53_zone.public[0].name
#   type    = "A"
#   ttl     = "300"
#   records = [for _, eip in aws_eip.eip : eip.public_ip] # List comprehension to access public_ip for each Elastic IP
# }

# DNS records: CNAME
resource "aws_route53_record" "cname" {
  zone_id = aws_route53_zone.public[0].zone_id #only interested in registering with zone 0
  name    = "www.${aws_route53_zone.public[0].name}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_route53_zone.public[0].name}."] #cnames must terminate with a full-stop
}

# Define the health check resource
resource "aws_route53_health_check" "http" {
  for_each = aws_eip.eip
  ip_address        = each.value.public_ip
  port              = 80 
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 10
  tags              = { Name = "HTTP:${each.value.public_ip}" }
  depends_on = [ aws_eip.eip ]
}

# Define Traffic Flow Policy
resource "aws_route53_traffic_policy" "www" {
  name     = "mydomain.com"
  comment  = "depdning on ec2 instance availability"
  document = <<EOF
{
  "AWSPolicyFormatVersion": "2023-05-09",
  "RecordType": "A",
  "Endpoints": {
    "endpoint-multivalue-tZEH": {
      "Type": "value",
      "Value": "${aws_route53_health_check.http[0].ip_address}"
    },
    "endpoint-multivalue-Vdgm": {
      "Type": "value",
      "Value": "${aws_route53_health_check.http[1].ip_address}"
    }
  },
  "Rules": {
    "multivalue-start-oKSk": {
      "RuleType": "multivalue",
      "Items": [
        {
          "EndpointReference": "endpoint-multivalue-tZEH",
          "HealthCheck": "${aws_route53_health_check.http[0].id}"
        },
        {
          "HealthCheck": "${aws_route53_health_check.http[1].id}",
          "EndpointReference": "endpoint-multivalue-Vdgm"
        }
      ]
    }
  },
  "StartRule": "multivalue-start-oKSk"
}
EOF
    depends_on = [ aws_route53_health_check.http, aws_eip.eip ]
}

resource "aws_route53_traffic_policy_instance" "www" {
  name                   = "mydomain.com"
  traffic_policy_id      = aws_route53_traffic_policy.www.id
  traffic_policy_version = 1
  hosted_zone_id         = aws_route53_zone.public[0].id
  ttl                    = 60 # Low TTL value, to improve failover times
}

# Generate RSA keys 
resource "tls_private_key" "rsa" {
  for_each  = var.project.compute.key_pairs
  algorithm = each.value.algorithm
  rsa_bits  = each.value.rsa_bits
}

# Generate random passwords
resource "random_password" "generated" {
  for_each         = var.project.compute.credentials
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Export the TLS Private Key into OpenSSH format (pem)
resource "local_file" "export_tls_private_key" {
  content    = tls_private_key.rsa[0].private_key_openssh
  filename   = "privatekey.pem"
  depends_on = [tls_private_key.rsa]
}

# Convert the OpenSSH file to a Putty supported format (ppk)
resource "null_resource" "convert_private_key_to_ppk" {
  provisioner "local-exec" { command = "winscp.com /keygen privatekey.pem /output=privatekey.ppk" }
  depends_on = [local_file.export_tls_private_key]
}

# the OpenSSH formatted public key
resource "aws_key_pair" "rsa" {
  for_each   = var.project.compute.key_pairs
  key_name   = each.value.key_name
  public_key = tls_private_key.rsa[each.key].public_key_openssh
  depends_on = [tls_private_key.rsa]
}

##################################
#               RDS              #
##################################
# DB SUBNET
resource "aws_db_subnet_group" "rds" {
  for_each    = var.project.compute.rds.subnet_groups
  name        = each.value.name
  description = each.value.description
  subnet_ids = [
    for subnet_key in each.value.subnet_keys : aws_subnet.subnets["${each.key}-${subnet_key}"].id
  ]
  tags = try(each.value.tags, var.project.tags)
}

# RDS Cluster param group
resource "aws_rds_cluster_parameter_group" "rds" {
  for_each    = var.project.compute.rds.cluster_parameter_groups
  name        = try(each.value.name, null)
  family      = each.value.family
  description = each.value.description
  dynamic "parameter" {
    for_each = try(each.value.parameters, {})
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [name_prefix, description]
  }
}

# RDS Cluster
resource "aws_rds_cluster" "rds" {
  for_each                         = try(var.project.compute.rds.cluster, {})
  allow_major_version_upgrade      = each.value.allow_major_version_upgrade
  apply_immediately                = each.value.apply_immediately
  backup_retention_period          = each.value.backup_retention_period
  cluster_identifier               = each.value.name
  copy_tags_to_snapshot            = each.value.copy_tags_to_snapshot
  database_name                    = each.value.database_name
  availability_zones               = try(each.value.availability_zones, null)
  db_cluster_parameter_group_name  = try(aws_rds_cluster_parameter_group.rds[each.value.cluster_parameter_group_key].name, "default.aurora-mysql8.0")
  db_instance_parameter_group_name = aws_db_parameter_group.rds[each.value.db_parameter_group_key].name
  db_subnet_group_name             = aws_db_subnet_group.rds[each.value.db_subnet_group_key].name
  vpc_security_group_ids           = [aws_security_group.sg[each.value.security_group_key].id]
  deletion_protection              = try(each.value.deletion_protection, false)
  engine                           = try(each.value.engine, "aurora-mysql")
  engine_mode                      = try(each.value.engine_mode, "serverless")
  engine_version                   = try(each.value.engine_version, "aurora-mysql8.0")
  storage_encrypted                = try(each.value.storage_encrypted, false)
  preferred_backup_window          = try(each.value.preferred_backup_window, "01:00-03:00")
  preferred_maintenance_window     = try(each.value.preferred_maintenance_window, "Sat:01:00-Sat:03:00")
  master_username                  = var.project.compute.credentials[each.value.password_key].username
  master_password                  = random_password.generated[each.value.password_key].result
  skip_final_snapshot              = null
  final_snapshot_identifier        = "DELETE-ME"
  scaling_configuration {
    auto_pause               = true
    max_capacity             = 4
    min_capacity             = 2
    seconds_until_auto_pause = 300
    timeout_action           = "ForceApplyCapacityChange"
  }
  lifecycle {
    ignore_changes = [
      # See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster#replication_source_identifier
      # Since this is used either in read-replica clusters or global clusters, this should be acceptable to specify
      replication_source_identifier,
      # See docs here https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_global_cluster#new-global-cluster-from-existing-db-cluster
      global_cluster_identifier,
      snapshot_identifier,
      availability_zones,
    ]
  }
}

# DB PARAMS
# Specify parameters that belong inside the RDS DB Params Group
resource "aws_db_parameter_group" "rds" {
  for_each = var.project.compute.rds.db_parameter_groups
  name     = replace(each.value.name, ".", "-")
  family   = each.value.family
  dynamic "parameter" {
    for_each = each.value.parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }
}

##################################
#             COMPUTE            #
##################################

# Create the EC2 Instance to host the web-frontend on
resource "aws_instance" "ec2" {
  for_each                    = var.project.compute.ec2
  ami                         = try(each.value.ami, data.aws_ami.ami_lookup["${each.value.os}"].id) # fallback to the free tier
  instance_type               = try(each.value.instance_type, "t2.micro")
  subnet_id                   = aws_subnet.subnets["${each.value.vpc_key}-${each.value.subnet_key}"].id
  vpc_security_group_ids      = [aws_security_group.sg[each.value.security_group_key].id]
  key_name                    = aws_key_pair.rsa[each.value.key_pair_key].key_name
  user_data                   = try(var.project.compute.user_data[each.value.user_data_key].commands, null)
  user_data_replace_on_change = true # useful for making adjustments to user_data block, simply apply again
  tags                        = try(each.value.tags, var.project.tags)
  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.rsa[0].private_key_openssh
    timeout     = "30s"
  }
  lifecycle {
    ignore_changes = [ami]
  }
}

# NOTE: On the SimpliLearn lab, these resources were explicitly denied - I raised this issue, and many others, support took a long time to rectify.
# "Error: updating IAM Policy (arn:aws:iam::342014086957:policy/ec2_scheduler): AccessDenied: User: arn:aws:iam::342014086957:user/odl_user_1273984 is not authorized to perform: iam:CreatePolicyVersion on resource: policy arn:aws:iam::342014086957:policy/ec2_scheduler with an explicit deny in an identity-based policy
#  status code: 403, request id: 46ee252d-25b0-4fc7-80aa-dca76cbd889b"
# # EC2 Scheduler Policy
# resource "aws_iam_policy" "ec2_scheduler" {
#   name = "ec2_scheduler"
#   policy = jsonencode( {
#       "Version": "2012-10-17",
#       "Statement": [{
#         "Sid": "EC2SchedulerStatement",
#         "Effect": "Allow",
#         "Action": [ "ec2:StartInstances", "ec2:StopInstances" ],
#         "Resource": [ "${aws_instance.ec2[0].arn}:*", "${aws_instance.ec2[1].arn}" ],
#       }]
#     }
#   )
# }
# # EC2 IAM Scheduler Role
# resource "aws_iam_role" "scheduler_role" {
#   name = "scheduler-ec2-role"
#   managed_policy_arns = [aws_iam_policy.ec2_scheduler.arn]
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action = "sts:AssumeRole"
#       Effect = "Allow"
#       Sid    = ""
#       Principal = { Service = "scheduler.amazonaws.com" }
#     }]
#   })
# }
# # START INSTANCES
# resource "aws_scheduler_schedule" "start" {
#   name       = "start-scheduler"
#   group_name = "default"
#   flexible_time_window { mode = "OFF" }
#   schedule_expression = "cron(0 9 ? * 2-6 *)" #M-F @ 9:00am
#   target {
#     arn      = "arn:aws:scheduler:::aws-sdk:ec2:startInstances"
#     role_arn = aws_iam_role.scheduler_role.arn
#     input = jsonencode({ InstanceIds = values(aws_instance.ec2)[*].id })
#   }
# }
# # STOP INSTANCES
# resource "aws_scheduler_schedule" "stop" {
#   name       = "stop-scheduler"
#   group_name = "default"
#   flexible_time_window { mode = "OFF" }
#   schedule_expression = "cron(30 23 ? * 1-7 *)" # Daily @ 11:30pm
#   target {
#     arn      = "arn:aws:scheduler:::aws-sdk:ec2:stopInstances"
#     role_arn = aws_iam_role.scheduler_role.arn
#     input = jsonencode({ InstanceIds = values(aws_instance.ec2)[*].id })
#   }
# }


# Configure Wordpress, passing parameters
# Login to SSH using private-key, write wp-setup commands, substituting wp user and wp pass.
# Login to mysql as root user, issue wp-setup commands.
resource "null_resource" "configure_wordpress_db" {
  #login via ssh - only need to login to one box
  connection {
    type        = "ssh"
    user        = "ubuntu" #"ec2-user"
    host        = aws_eip.eip[0].public_ip                   # SSH to the public ip isn't secure, but the SSH port is not going to be open forever
    private_key = tls_private_key.rsa[0].private_key_openssh # one SSH Key per ec2 instance
    timeout     = "30s"
  }
  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "sudo apt install --yes mysql-client-core-8.0",
      "# Setup the WP Database",
      "echo \"DROP USER `wordpress`@`%`;\" > commands.sql",
      "echo \"CREATE USER `${var.project.compute.credentials[1].username}`@`%` IDENTIFIED BY `${random_password.generated[1].result}`;\" > commands.sql",
      "echo \"CREATE DATABASE '${aws_rds_cluster.rds[0].database_name}';\" >> commands.sql",
      "echo \"GRANT ALL PRIVILEGES ON `${aws_rds_cluster.rds[0].database_name}`.`*` TO `${var.project.compute.credentials[1].username}`@`*` WITH GRANT OPTION;\" >> commands.sql",
      "echo \"FLUSH PRIVILEGES;\" >> commands.sql",
      "echo \"EXIT;\" >> commands.sql",
      "mysql --host=${aws_rds_cluster.rds[0].endpoint} --user=${var.project.compute.credentials[0].username} --password='${random_password.generated[0].result}' < commands.sql",
      "/bin/rm -f comamnds.sql"
    ]
  }
  # we MUST wait for the EC2 instance to boot; executing the user_data one-time-boot script, installing wp etc before we can configure it
  depends_on = [tls_private_key.rsa, aws_instance.ec2, aws_eip.eip, aws_rds_cluster.rds]
}

# Configure Wordpress mysql user
resource "null_resource" "configure_wordpress_frontend" {
  for_each = var.project.compute.ec2
  #login via ssh
  connection {
    type        = "ssh"
    user        = "ubuntu" # or ec2-user
    host        = aws_eip.eip[each.key].public_ip
    private_key = tls_private_key.rsa[each.value.key_pair_key].private_key_openssh
    timeout     = "30s"
  } 
  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "# Automate Latest Wordpress Installation on Ubuntu with Apache",
      "sudo apt-get update -y",
      "sudo apt install --yes php php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip php-mysql",
      "# Download wordpress package and extract",
      "sudo wget --progress=bar:force:noscroll https://wordpress.org/latest.tar.gz",
      "sudo tar -xzf latest.tar.gz",
      "sudo cp -r ./wordpress/* /var/www/html/",
      "sudo rm -rf ./wordpress ./latest.tar.gz",
      "# Ensure correct file/folder ownership",
      "sudo chown -R ubuntu:www-data /var/www",
      "# Disable the default site",
      "sudo a2dissite 000-default",
      "sudo rm /var/www/html/index.html",
      "AP_CONFIG='/etc/apache2/sites-available/wordpress.conf'",
      "cat << EOF | sudo tee $AP_CONFIG > /dev/null",
      "<VirtualHost *:80>",
      "  ServerName example.com",
      "  Alias www.example.com",
      "  DocumentRoot '/var/www/html'",
      "  <Directory '/var/www/html'>",
      "    Require all granted",
      "    DirectoryIndex index.php",
      "    AllowOverride FileInfo",
      "    FallbackResource /index.php",
      "  </Directory>",
      "  <Directory '/var/www/html/wp-admin'>",
      "    FallbackResource disabled",
      "  </Directory>",
      "  ProxyPassMatch ^/(.*\\.php(/.*)?)$ unix:/var/run/php/php-fpm.sock|fcgi://dummy/var/www/wordpress",
      "</VirtualHost>",
      "EOF",
      "sudo sed -i 's|example.com|${var.project.domains[0].name}|g' $AP_CONFIG;",
      "# Enable the new site in apache",
      "sudo a2ensite wordpress",
      "# Copy the sample wp-config file out",      
      "WP_CONFIG='/var/www/html/wp-config.php'",
      "sudo cp /var/www/html/wp-config-sample.php $WP_CONFIG",
      "# Update wp-config.php file with database details",
      "sed -i 's|database_name_here|${aws_rds_cluster.rds[0].database_name}|g' $WP_CONFIG;",
      "sed -i 's|username_here|${var.project.compute.credentials[1].username}|g' $WP_CONFIG;",
      "sed -i 's|password_here|${random_password.generated[1].result}|g' $WP_CONFIG;",
      "sed -i 's|localhost|${aws_rds_cluster.rds[0].endpoint}|g' $WP_CONFIG;",
      "# port:${aws_rds_cluster.rds[0].port}",
      "# Fetch salts from WordPress API",
      "SALT=$(curl -L 'https://api.wordpress.org/secret-key/1.1/salt/')",
      "# Replace existing salts in wp-config.php with the fetched ones",
      "sed -i \"/put your unique phrase here/d\" $WP_CONFIG;",
      "echo \"$SALT\" >> $WP_CONFIG",
      "sudo systemctl restart apache2"
    ]
    #on_failure = continue
  }
  depends_on = [ tls_private_key.rsa, aws_instance.ec2, aws_eip.eip, null_resource.configure_wordpress_db ]
}




output "DB_HOST" {
  value = aws_rds_cluster.rds[0].endpoint
}
output "DB_NAME" {
  value = aws_rds_cluster.rds[0].database_name
}
output "DB_USER" {
  value = var.project.compute.credentials[1].username
}
output "DB_PASSWORD" {
  value     = random_password.generated[1].result
  sensitive = true
}

output "PUBLIC_IP_ADDRESSES" {
  value = [aws_eip.eip["0"].public_ip, aws_eip.eip["1"].public_ip]
}


output "WP_ADMIN_USER" {
  value = "not set"
}
output "WP_ADMIN_PASSWORD" {
  value = "not set"
}
output "WEBSITE" {
  value = "http://www.${aws_route53_zone.public[0].name}"
}