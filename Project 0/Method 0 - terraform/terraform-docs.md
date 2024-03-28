<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 4.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 4.67.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.5.1 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.2 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.6.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.0.5 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_db_parameter_group.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
| [aws_db_subnet_group.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_efs_file_system.efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system) | resource |
| [aws_efs_mount_target.attach](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target) | resource |
| [aws_eip.eip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_instance.ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_internet_gateway.igws](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_key_pair.rsa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair) | resource |
| [aws_rds_cluster.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster) | resource |
| [aws_rds_cluster_parameter_group.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_parameter_group) | resource |
| [aws_route53_health_check.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_health_check) | resource |
| [aws_route53_record.cname](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_traffic_policy.www](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_traffic_policy) | resource |
| [aws_route53_traffic_policy_instance.www](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_traffic_policy_instance) | resource |
| [aws_route53_zone.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_route_table.route_tables](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.route_table_associations](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.networks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [local_file.export_tls_private_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.configure_apache2](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.configure_wordpress_db](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.convert_private_key_to_ppk](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.efs_mount](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.install_wordpress_frontend](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.symlinks](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_password.generated](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [tls_private_key.rsa](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [aws_ami.ami_lookup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ami_lookup"></a> [ami\_lookup](#input\_ami\_lookup) | n/a | `map(any)` | <pre>{<br>  "amazonlinux2": {<br>    "filters": [<br>      {<br>        "name": "name",<br>        "values": [<br>          "amzn2-ami-hvm-*-x86_64-gp2"<br>        ]<br>      },<br>      {<br>        "name": "virtualization-type",<br>        "values": [<br>          "hvm"<br>        ]<br>      }<br>    ],<br>    "most_recent": true,<br>    "owners": [<br>      "amazon"<br>    ]<br>  },<br>  "ubuntu": {<br>    "filters": [<br>      {<br>        "name": "name",<br>        "values": [<br>          "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"<br>        ]<br>      },<br>      {<br>        "name": "virtualization-type",<br>        "values": [<br>          "hvm"<br>        ]<br>      }<br>    ],<br>    "most_recent": true,<br>    "owners": [<br>      "099720109477"<br>    ]<br>  }<br>}</pre> | no |
| <a name="input_project"></a> [project](#input\_project) | Declare a single variable for your project Note: no need to be specific with data types | `map` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_DB_HOST"></a> [DB\_HOST](#output\_DB\_HOST) | n/a |
| <a name="output_DB_NAME"></a> [DB\_NAME](#output\_DB\_NAME) | n/a |
| <a name="output_DB_PASSWORD"></a> [DB\_PASSWORD](#output\_DB\_PASSWORD) | n/a |
| <a name="output_DB_USER"></a> [DB\_USER](#output\_DB\_USER) | n/a |
| <a name="output_PUBLIC_IP_ADDRESSES"></a> [PUBLIC\_IP\_ADDRESSES](#output\_PUBLIC\_IP\_ADDRESSES) | n/a |
| <a name="output_WEBSITE"></a> [WEBSITE](#output\_WEBSITE) | n/a |
| <a name="output_WP_ADMIN_PASSWORD"></a> [WP\_ADMIN\_PASSWORD](#output\_WP\_ADMIN\_PASSWORD) | n/a |
| <a name="output_WP_ADMIN_USER"></a> [WP\_ADMIN\_USER](#output\_WP\_ADMIN\_USER) | n/a |
<!-- END_TF_DOCS -->