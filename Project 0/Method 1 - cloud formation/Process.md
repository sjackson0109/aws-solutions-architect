Create a Key-Pair
 name: sjackson
 type: rsa
 format: pem

Create VPC
 2x Availabilty Zones, and with 2x public subnets, and 2x private subnets.
 Internet Gateway attached to the default route.
 Dedicated route-table for private subnets, with a dedicated NAT gateway for outbound WAN access only from private subnets.
 No custom Security Groups yet; would be necessary for production. Although NSGs might be easier!

Create a new CloudFormation Stack, with Wordpress-HA Template, selecting Single Instance for web-frontend.
 Includes Application Load Balancer with ALB Listener and ALB Target Group, with ALB Security Group
 database: wordpressdb
 username: wordpressusr
 password: wordpresspwd



Convert the configured instance, to an AIM image template

Destroy the Cloud Formation Instance (leaving AIM image)
