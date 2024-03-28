project = {
  tags = {
    owner   = "Simon Jackson"
    course  = "AWS Solutions Architect"
    project = "Setup and Monitor Wordpress - running in HA on EC2 Instances"
  }
  aux = {
    wp_debug = false #false/true
  }
  domains = {
    0 = {
      name          = "mydomain.com"
      auto_renew    = false
      transfer_lock = false
      name_servers = [
        "ns-314.awsdns-39.com",
        "ns-727.awsdns-26.net",
        "ns-1384.awsdns-45.org",
        "ns-1872.awsdns-42.co.uk"
      ]
      contacts = {
        registrant = {

        }
        admin = {

        }
        tech = {

        }
      }
      privacy_protection = true
    }
  }
  networking = {
    vpcs = {
      0 = {
        tags                 = { Name = "wordpress-vpc" }
        cidr_block           = "10.101.0.0/16"
        instance_tenancy     = "default"
        enable_dns_support   = true
        enable_dns_hostnames = true
        subnets = {
          0 = {
            tags              = { Name = "pub-us-east-1a" }
            cidr_block        = "10.101.0.0/24"
            availability_zone = "us-east-1a"
            route_table_key   = 0 # public routes in rt0
            eip_key           = 2 # nat gw eip
          }
          1 = {
            tags              = { Name = "pub-us-east-1b" }
            cidr_block        = "10.101.1.0/24"
            availability_zone = "us-east-1b"
            route_table_key   = 0 # private routes in rt0
            eip_key           = 3 # nat gw eip
          }
          2 = {
            tags              = { Name = "priv-us-east-1a" }
            cidr_block        = "10.101.2.0/24"
            availability_zone = "us-east-1a"
            route_table_key   = 1 # private routes in rt1
          }
          3 = {
            tags              = { Name = "priv-us-east-1b" }
            cidr_block        = "10.101.3.0/24"
            availability_zone = "us-east-1b"
            route_table_key   = 1 # private routes in rt1
          }
        }
      }
    }
    route_tables = {
      0 = { #public
        tags             = { Name = "public-rt" }
        parent_vpc_key   = 0
        propagating_vgws = false
        routes = {
          0 = {
            cidr_block = "0.0.0.0/0"
            next_hop   = "igw"
          }
        }
      }
      1 = { #private
        tags             = { Name = "private-rt" }
        parent_vpc_key   = 0
        propagating_vgws = true
        routes = {
          # 0 = {
          #     name = "private_traffic"
          #     cidr_block = "10.99.1.0/24"
          #     next_hop = "vpc"
          # }
        }
      }
    }
    internet_gateways = {
      0 = {
        tags           = { Name = "wp-igw" }
        parent_vpc_key = 0
      }
    }
    load_balancers = {
      0 = {
        name                = "wp-lb"
        subnet_keys         = ["2", "3"]
        security_group_keys = [""]
        listeners = {
          0 = {
            fqdn          = "sjackson0109.click"
            public_facing = true
            idle_timeout  = 60
            protocol      = "http"
            backend_key   = 0
            lb_key        = 0
          }
          1 = {
            fqdn          = "sjackson0109.click"
            public_facing = true
            idle_timeout  = 60
            protocol      = "https"
            backend_key   = 0
            lb_key        = 0
          }
        }
        targets = {
          0 = {
            name     = "backend"
            protocol = "http"
            persistence = {
              duration = 1800
              sticky   = true
            }
            health_checks = {
              port = 80
              path = "/"
            }
          }
        }
        rules = {
          0 = {
            priority     = 100
            backend_key  = 0
            frontend_key = 0
          }
        }
      }
    }
    elastic_ip_addresses = { #must be created AFTER the internet gateway. not possible to associate beforehand
      0 = {
        ec2_instance_key = 0
      }
      1 = {
        ec2_instance_key = 1
      }
      2 = {
        lb_instance_key = 0
      }
    }

    security_groups = {
      0 = {
        vpc_key     = 0
        name        = "frontend-sg"
        description = "Allow ingress HTTP/S, and administrators HTTPS only"
        ingress_rules = {
          0 = {
            name        = "ssh"
            source_cidr = ["51.6.187.228/32"] # home wan ip
            protocol    = "tcp"
            from_port   = 0
            to_port     = 22 # ssh
          }
          1 = {
            name        = "http"
            source_cidr = ["0.0.0.0/0"]
            protocol    = "tcp"
            from_port   = 0
            to_port     = 80 # http
          }
          2 = {
            name        = "https"
            source_cidr = ["0.0.0.0/0"]
            protocol    = "tcp"
            from_port   = 0
            to_port     = 443 # https
          }
        }
        egress_rules = {
          0 = {
            name             = "ntp"
            protocol         = "udp"
            from_port        = 0
            to_port          = 123 # ntp
            destination_cidr = ["0.0.0.0/0"]
          }
          1 = {
            name             = "dns/udp"
            protocol         = "udp"
            from_port        = 0
            to_port          = 53 # dns
            destination_cidr = ["0.0.0.0/0"]
          }
          1 = {
            name             = "dns/tcp"
            protocol         = "udp"
            from_port        = 0
            to_port          = 53 # dns
            destination_cidr = ["0.0.0.0/0"]
          }
          2 = {
            name             = "http"
            protocol         = "tcp"
            from_port        = 0
            to_port          = 80 # http
            destination_cidr = ["0.0.0.0/0"]
          }
          3 = {
            name             = "https"
            protocol         = "tcp"
            from_port        = 0
            to_port          = 443 # https
            destination_cidr = ["0.0.0.0/0"]
          }
          4 = {
            name             = "mysql"
            protocol         = "tcp"
            from_port        = 0
            to_port          = 3306                               # mysql
            destination_cidr = ["10.101.2.0/24", "10.101.3.0/24"] # target backend subnet / rds
          }
          5 = {
            name             = "efs"
            protocol         = "tcp"
            from_port        = 0
            to_port          = 2049          # efs
            destination_cidr = ["0.0.0.0/0"] # target = efs service, unknown endpoint
          }
        }
      }
      1 = {
        vpc_key     = 0
        name        = "backend-sg"
        description = "allow "
        ingress_rules = {
          0 = {
            name        = "mysql"
            source_cidr = ["10.101.0.0/24", "10.101.1.0/24"] #frontend subnet
            protocol    = "tcp"
            from_port   = 0
            to_port     = 3306 # http
          }
        }
        egress_rules = {
          0 = {
            name             = "ntp"
            protocol         = "udp"
            from_port        = 0
            to_port          = 123 # ntp
            destination_cidr = ["0.0.0.0/0"]
          }
          1 = {
            name             = "dns/udp"
            protocol         = "udp"
            from_port        = 0
            to_port          = 53 # dns/udp
            destination_cidr = ["0.0.0.0/0"]
          }
          2 = {
            name             = "dns/tcp"
            protocol         = "tcp"
            from_port        = 0
            to_port          = 53 # dns/tcp
            destination_cidr = ["0.0.0.0/0"]
          }
          3 = {
            name             = "http"
            protocol         = "tcp"
            from_port        = 0
            to_port          = 80 # http
            destination_cidr = ["0.0.0.0/0"]
          }
          4 = {
            name             = "https"
            protocol         = "tcp"
            from_port        = 0
            to_port          = 443 # https
            destination_cidr = ["0.0.0.0/0"]
          }
        }
      }
      2 = {
        vpc_key     = 0
        name        = "lb-sg"
        description = "allow "
        ingress_rules = {
          0 = {
            name        = "http"
            source_cidr = ["0.0.0.0/0"]
            protocol    = "tcp"
            from_port   = 0
            to_port     = 80 # http
          }
          1 = {
            name        = "http"
            source_cidr = ["0.0.0.0/0"]
            protocol    = "tcp"
            from_port   = 0
            to_port     = 80 # http
          }
        }
        egress_rules = {
          0 = {
            name             = "http"
            protocol         = "tcp"
            from_port        = 0
            to_port          = 80 # http
            destination_cidr = ["0.0.0.0/0"]
          }
          1 = {
            name             = "https"
            protocol         = "tcp"
            from_port        = 0
            to_port          = 443 # https
            destination_cidr = ["0.0.0.0/0"]
          }
        }
      }
    }
  } #networking
  storage = {
    efs = {
      0 = {
        encrypted        = true
        performance_mode = "generalPurpose"
        throughput_mode  = "bursting"
        lifecycle_policy = {
          transition_to_ia = "AFTER_30_DAYS"
        }
        tags = {
          name          = "wordpress-data"
          mount_point   = "/mnt/efs/data"
          symbolic_link = "/var/www/html"
          owner         = "ubuntu"
          group         = "www-data"
          permission    = "665"
        }
      }
    }
  } #stoage
  compute = {
    rds = {
      cluster = {
        0 = {
          name                        = "wordpress"
          database_name               = "wordpress"
          availability_zones          = ["us-east-1a", "us-east-1b"]
          backup_retention_period     = 31
          apply_immediately           = true
          allow_major_version_upgrade = true
          copy_tags_to_snapshot       = true
          deletion_protection         = false
          engine                      = "aurora-mysql"
          engine_mode                 = "serverless" #serverless or provisioned
          engine_version              = "5.7.mysql_aurora.2.11.4"
          instance_class              = "db.serverless"
          cluster_parameter_group_key = 0
          db_parameter_group_key      = 0
          db_subnet_group_key         = 0
          security_group_key          = 1 # 0=public, 1=private
          username_key                = 0
          password_key                = 0
          storage_encrypted           = true
          monitoring_interval         = 60
          serverlessv2_scaling_configuration = {
            max_capacity = 0.5
            max_capacity = 1
          }
          preferred_backup_window      = "23:00-00:00"
          preferred_maintenance_window = "Thu:01:00-Thu:03:00"
        }
      }
      cluster_parameter_groups = {
        0 = {
          name        = "mysql57"
          family      = "aurora-mysql5.7"
          description = "Database cluster parameters"
        }
      }
      subnet_groups = {
        0 = { # group0 - linking subnet1 to vpc0, with the db instances
          name        = "application"
          description = "rds database backend subnets"
          subnet_keys = ["2", "3"]
        }
      }
      db_parameter_groups = {
        0 = {
          name   = "mysql57" #only lowercase, with hyphens allowed
          family = "mysql5.7"
          parameters = {
            # 0 = {
            #   name  = "log_connections"
            #   value = "1"
            # }
          }
        }
      }
      # Instances are not necessary in a serverless, and scalable cluster
      # instances = {
      #   0 = {
      #     cluster_key = 0
      #     apply_immediately = true
      #     auto_minor_version_upgrade = true
      #     publically_accessible = false
      #     db_parameter_group_key = 0
      #     db_subnet_group_key = 0
      #     instance_class              = "db.t2.micro"


      #     allocated_storage           = 10 #gb
      #     subnet_group_key            = 0
      #     security_group_key          = 1 # sg0=public, sg1=private
      #     identifier                  = "wordpress"
      #     db_name                     = "wordpress"
      #     engine                      = "mysql"
      #     engine_version              = "5.7.44"
      #     username                    = "rds_user"
      #     password_key                = 0
      #     parameter_group_key         = 0
      #     storage_encrypted           = true
      #     skip_final_snapshot         = true
      #     multi_az                    = true                  # high availability needed
      #     backup_retention_period     = 7                     # bc
      #     backup_window               = "02:00-03:00"         # 30+min window, cannot overlap maintenance_window
      #     maintenance_window          = "Mon:00:00-Mon:01:00" #30+min window, cannot overlap backup_window, weekly
      #     allow_major_version_upgrade = true                  # for non-production, why not
      #     tags                        = { Name = "myrds" }
      #   }
      # }
    }
    user_data = {
      0 = { #ec2 instance first-boot commands, installing wordpress 
        commands = <<EOF
          #!/bin/bash
          # Automate Latest Wordpress Installation on Ubuntu with Apache
          sudo apt-get update -y
          sudo apt install --yes php php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip php-mysql mysql-client-core-8.0

          # Download wordpress package and extract
          sudo wget --progress=bar:force:noscroll https://wordpress.org/latest.tar.gz
          sudo tar -xzf latest.tar.gz 
          sudo cp -r ./wordpress/* /var/www/html/
          sudo rm -rf ./wordpress ./latest.tar.gz

          # Ensure correct file/folder ownership
          sudo chown -R ubuntu:www-data /var/www

          # Disable the default site
          sudo a2dissite 000-default
          sudo rm /var/www/html/index.html

          /etc/apache2/sites-available/wordpress.conf
          sudo a2ensite wordpress

          sudo cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

          # Hardening wp
          find /var/www -type d -exec sudo chmod 2775 {} \;
          find /var/www -type f -exec sudo chmod 0664 {} \;
          sudo chmod -R 770 /var/www/html/wp-content
          sudo chmod -R g-w /var/www/html/wp-admin /var/www/html/wp-includes /var/www/html/wp-content/plugins

          # Allow .htaccess overrides at directory level, for all sites
          sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride all/' /etc/apache2/apache2.conf
          sudo a2enmod rewrite

          # STARTUP
          sudo systemctl enable httpd
          sudo systemctl restart httpd
        EOF
      }
    }
    key_pairs = {
      0 = {
        key_name            = "sjackson"
        algorithm           = "RSA"
        rsa_bits            = 2048
        public_key_filename = "../ec2_instance_01.pub"
      }
    }
    credentials = {
      0 = {
        name     = "rds_root"
        username = "root" #default, cannot change
      }
      1 = {
        name     = "rds_wordpress_user"
        username = "wordpress"
      }
    }
    ec2 = { # HA FrontEnd, requires 2x or more web-servers
      0 = {
        tags = { Name = "wordpress-0" }
        os   = "ubuntu" #grab the latest from a given os
        #ami                = "ami-0e731c8a588258d0d" #Amazon Linux #aim-026ad73ed895934d6" #Ubuntu LTS 23.10 x64
        instance_type      = "t2.micro"
        vpc_key            = 0
        subnet_key         = 0
        security_group_key = 0 #public
        key_pair_key       = 0 #rsa key
        user_data_key      = 0 #wordpress-shared
        efs_key            = 0
      }
      1 = {
        tags = { Name = "wordpress-1" }
        os   = "ubuntu" #grab the latest from a given os
        #ami                = "ami-0e731c8a588258d0d" #Ubuntu LTS 23.10 x64
        instance_type      = "t2.micro"
        vpc_key            = 0
        subnet_key         = 1 # second instance MUST be in a different subnet!
        security_group_key = 0 #public
        key_pair_key       = 0 #rsa key
        user_data_key      = 0 #wordpress-shared
        efs_key            = 0
      }
    }
  }
}