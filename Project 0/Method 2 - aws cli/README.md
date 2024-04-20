## Note to the reader

The steps described below are to satisfy the tasklist identified for [Project 0](../README.md) in the parent folder.

## Step-by-step Instructions (AWS CLI)
0. Start the AWS LAB, and login via CLI:

    Launch a command line.
    Enter the following parameters:
    ```powershell
    $env:AWS_ACCESS_KEY_ID="{REDACTED}"
    $env:AWS_SECRET_ACCESS_KEY="{REDACTED}"
    $env:AWS_REGION="us-east-1"
    ```

1. Navigate to the VPC area, and Create a VPC:

    Specifics: - 2x route tables, 2x availability zones, 2x public subnets, 2x private subnets, and 1 NATGW per-AZ.

      - Create a VPC, with name:`wordpress-vpc`, base-cidr:`10.101.0.0/16`
        ```powershell
        aws ec2 create-vpc --cidr-block 10.101.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=wordpress-vpc}]'
        aws ec2 create-route-table --vpc-id <vpc-id> --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=public-rt}]'
        aws ec2 create-route-table --vpc-id <vpc-id> --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=private-rt}]'
        ```

      - Create 2x Public facing subnets, in two different Availability Zones.
      - Create 2x Private subnets, in two different Availability Zones.
      - Associate the Private subnets are associated with the correct route-table.
        ```powershell
        aws ec2 create-subnet --vpc-id <vpc-id> --cidr-block 10.101.0.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=pub-us-east-1a}]'
        aws ec2 create-subnet --vpc-id <vpc-id> --cidr-block 10.101.1.0/24 --availability-zone us-east-1b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=pub-us-east-1b}]'
        aws ec2 create-subnet --vpc-id <vpc-id> --cidr-block 10.101.2.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=priv-us-east-1a}]'
        aws ec2 create-subnet --vpc-id <vpc-id> --cidr-block 10.101.3.0/24 --availability-zone us-east-1b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=priv-us-east-1b}]'
        ```

      - Associate route tables with subnets:
        ```powershell
        aws ec2 associate-route-table --subnet-id <public-subnet-id> --route-table-id <public-route-table-id>
        aws ec2 associate-route-table --subnet-id <private-subnet-id> --route-table-id <private-route-table-id>
        ```

2. Search for `Key Pairs`. Create a key-pair.

      - Specifics: Key-Type=`RSA`, Private Key Out: `ppk format`
        ```powershell
        aws ec2 create-key-pair --key-name sjackson --query 'KeyMaterial' --output text > ec2_instance_01.pem
        ```

3. Search for Security Groups, Create:

    
    FRONTEND | public-sg:-
      - Ingress: HTTP/S, SSH
        ```powershell
        aws ec2 create-security-group --group-name frontend-sg --description "Allow ingress HTTP/S, and administrators HTTPS only" --vpc-id <vpc-id>
        aws ec2 authorize-security-group-ingress --group-id <frontend-sg-id> --protocol tcp --port 80 --cidr 0.0.0.0/0 --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=http}]'
        aws ec2 authorize-security-group-ingress --group-id <frontend-sg-id> --protocol tcp --port 443 --cidr 0.0.0.0/0 --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=https}]'
        aws ec2 authorize-security-group-ingress --group-id <frontend-sg-id> --protocol tcp --port 22 --cidr 51.6.187.228/32 --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=ssh}]'
        ```
      - Egress: NTP, DNS, HTTP/S, MYSQL(10.101.0.0/16)

        ```powershell
        aws ec2 authorize-security-group-egress --group-id <frontend-sg-id> --protocol udp --port 123 --cidr 0.0.0.0/0 --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=ntp}]'
        aws ec2 authorize-security-group-egress --group-id <frontend-sg-id> --protocol udp --port 53 --cidr 0.0.0.0/0 --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=dns/udp}]'
        aws ec2 authorize-security-group-egress --group-id <frontend-sg-id> --protocol tcp --port 53 --cidr 0.0.0.0/0 --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=dns/tcp}]'
        aws ec2 authorize-security-group-egress --group-id <frontend-sg-id> --protocol tcp --port 50 --cidr 0.0.0.0/0 --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=http}]'
        aws ec2 authorize-security-group-egress --group-id <frontend-sg-id> --protocol tcp --port 443 --cidr 0.0.0.0/0 --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=https}]'
        aws ec2 authorize-security-group-egress --group-id <frontend-sg-id> --protocol tcp --port 3306 --cidr 10.101.2.0/24 --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=mysql}]'
        aws ec2 authorize-security-group-egress --group-id <frontend-sg-id> --protocol tcp --port 3306 --cidr 10.101.3.0/24 --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=mysql}]'
        aws ec2 authorize-security-group-egress --group-id <frontend-sg-id> --protocol tcp --port 2049 --cidr 0.0.0.0/0 --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=efs}]'
        ```
            
         
    BACKEND | private-sg:-
      - Ingress: MySQL:tcp/3306 only
        ```powershell
        aws ec2 create-security-group --group-name backend-sg --description "allow" --vpc-id <vpc-id>
        aws ec2 authorize-security-group-ingress --group-id <backend-sg-id> --protocol tcp --port 3306 --cidr 10.101.0.0/24 --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=mysql}]'
        aws ec2 authorize-security-group-ingress --group-id <backend-sg-id> --protocol tcp --port 3306 --cidr 10.101.1.0/24 --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=mysql}]'
        aws ec2 authorize-security-group-ingress --group-id <backend-sg-id> --protocol tcp --port 3306 --cidr 10.101.0.0/24 --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=mysql}]'
        aws ec2 authorize-security-group-ingress --group-id <backend-sg-id> --protocol tcp --port 3306 --cidr 10.101.1.0/24 --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=mysql}]'
        ```

      - Egress: All Traffic (default)
        ```powershell
        aws ec2 authorize-security-group-egress --group-id <backend-sg-id> --protocol udp --port 123 --cidr 0.0.0.0/0 --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=ntp}]'
        ```

    LOAD BALANCER | lb-sg:-
      - Ingress: HTTP/HTTPS
        ```powershell
        aws ec2 authorize-security-group-ingress --group-id <lb-sg-id> --protocol tcp --port 80 --cidr 0.0.0.0/0 --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=http}]'
        aws ec2 authorize-security-group-ingress --group-id <lb-sg-id> --protocol tcp --port 443 --cidr 0.0.0.0/0 --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=https}]'
        ```

4. Build a Layer 5 Load Balancer:

      - With listeners, and target groups:
        ```powershell
        aws elbv2 create-load-balancer --name wp-lb --subnets <subnet-ids> --security-groups <lb-sg-id> --scheme internet-facing
        aws elbv2 create-listener --load-balancer-arn <load-balancer-arn> --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=<target-group-arn>
        aws elbv2 create-listener --load-balancer-arn <load-balancer-arn> --protocol HTTPS --port 443 --certificates CertificateArn=<certificate-arn> --ssl-policy ELBSecurityPolicy-2016-08 --default-actions Type=forward,TargetGroupArn=<target-group-arn
        aws elbv2 create-target-group --name backend --protocol HTTP --port 80 --vpc-id <vpc-id> --target-type instance
        ```

5. Create an Internet Gateway and attach it to the VPC
   
      - Create and Attach an Internet Gateway to the VPC:
        ```powershell
        aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=wp-igw}]'
        aws ec2 attach-internet-gateway --vpc-id <vpc-id> --internet-gateway-id <internet-gateway-id>
        ```

      - Update the public route table, to use this internet gateway:
        ```powershell
        aws ec2 create-route --route-table-id <route-table-id> --destination-cidr-block 0.0.0.0/0 --gateway-id <internet-gateway-id>
        ```

6. Create an RDS CLUSTER, with two instances

    Specifics: Aurora/MySQL mysql 8.0 compatible, serverless, multi-availability-zone, ensure `wordpress-vpc` selected, ipv4 only, use existing security group `backend-sg`
 
    Creating the Cluster, with Default DB Engine, attach to correct subnet, and security groups
    ```powershell
    aws rds create-db-cluster-parameter-group --db-cluster-parameter-group-name mysql80 --db-parameter-group-family aurora-mysql8.0 --description "Database cluster parameters"
    aws rds create-db-parameter-group --db-parameter-group-name mysql80 --db-parameter-group-family mysql8.0
    aws rds create-db-subnet-group --db-subnet-group-name application --db-subnet-group-description "rds database backend subnets" --subnet-ids <subnet-ids>
    aws rds create-db-cluster --db-cluster-identifier wordpress --engine aurora-mysql --engine-mode serverless --engine-version 8.0.mysql_aurora.3.04.1 --database-name wordpress --master-username `admin` --master-user-password `u2PcCz8Z5pj5` --backup-retention-period 31 --preferred-maintenance-window "Thu:01:00-Thu:03:00" --preferred-backup-window "23:00-00:00" --tags Key=Name,Value=wordpress
    aws rds create-db-instance --db-instance-identifier wordpress-writer --db-cluster-identifier wordpress --db-instance-class db.serverless --engine aurora-mysql --engine-version 8.0.mysql_aurora.3.04.1 --publicly-accessible --db-subnet-group-name application --monitoring-interval 60 --tags Key=Name,Value=writer
    aws rds create-db-instance --db-instance-identifier wordpress-reader --db-cluster-identifier wordpress --db-instance-class db.serverless --engine aurora-mysql --engine-version 8.0.mysql_aurora.3.04.1 --publicly-accessible --db-subnet-group-name application --monitoring-interval 60 --tags Key=Name,Value=reader
    ```

      - Capture the username and password: `u2PcCz8Z5pj5`

    ![Admin PWD](<../Method 1 - aws gui/05-rds-3-admin.png>)

      - Capture those credentials in a vault:
        ```powershell
        aws secretsmanager create-secret --name rds_root --secret-string <password>
        aws secretsmanager create-secret --name rds_wordpress_user --secret-string <password>
        ```


7. Create an Elastic File System
   
      - This is to be used as a data-disk for each EC2 Instance late; however needs creating and then associating with the VPC first:
        ```powershell
        aws efs create-file-system --encrypted --performance-mode generalPurpose --throughput-mode bursting --tags Key=Name,Value=wordpress-data
        ```
      - Describe the disk:
        ```powershell
        aws efs describe-file-systems
        ```

8. Create EC2 Instance
   
   Specify: OS=`Ubuntu LTS`, CPU Arch=`x64`, Instance-Type=`t2.micro`, network=`wordpress-vpc`, subnet=`pub-us-east-1a`, Security Group=`frontend-sg`, FileSystem=`wordpress-data` mounted to `/mnt/efs/data`


      - Prepare a User_Data startup script:
        ```bash
        #!/bin/bash
        sudo apt-get update -y
        sudo apt install --yes php php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip php-mysql mysql-client-core-8.0

        # Mount the EFS volume
        sudo mkdir -p /mnt/efs
        sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 <efs-dns-name>:/ /mnt/efs

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
        ```

      - Label the EC2 instance
        ```powershell
        aws ec2 run-instances --image-id <ami-id> --count 1 --instance-type t2.micro --key-name sjackson --security-group-ids <frontend-sg-id> --subnet-id <subnet-id> --user-data file://user_data.sh --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=wordpress-0}]' --block-device-mappings "[{\"DeviceName\":\"/dev/sdh\",\"Ebs\":{\"VolumeSize\":20,\"VolumeType\":\"gp2\",\"DeleteOnTermination\":false}}]"
        ```

      - Elastic IPs:
        ```powershell
        aws ec2 allocate-address --domain vpc
        aws ec2 allocate-address --domain vpc
        aws ec2 allocate-address --domain vpc
        ```

9. Prepare the Wordpress database
   
    SSH into the wordpress instance using the public IP address, or EC2 Console.
    
    ![View Public IP](<../Method 1 - aws gui/10-wp-pip.png>)

    Verify network connectivity to the RDS database instance. 
    
    ![Network Connection to RDS](<../Method 1 - aws gui/08-confirm-network-connectivity-to-db.png>)

    Execute the command `sudo apt install --yes mysql-client-core-8.0` so that we can actually login to RDS with a mysql client. Login using `mysql -h <RDS ENDPOINT NAME> -u rds_user` with the password setup earlier. Create the both the `Wordpress` Database and Username, followed by `Grant all privileges`, `flushing privileges` at the end. 

    ![Create Wordpress DB](<../Method 1 - aws gui/08-create-wp-db.png>)

    NOTE: I repeated this command using the suffix `with grant option;`. After confirming all the necessary commands, i've subsequently extracted this to a `user_data` first-boot-script for my future EC2 instances.
   
10. Prepare the EFS Sym-links, if not already automated.

    Simply execute the `sudo ln -s /mnt/efs/data/html /var/www/html` command:
    
    ![Sym Links](<../Method 1 - aws gui/09-sym-links-to-efs-disk.png>)

    Note: if Apache was installed before executing this command, there is an error creating the target html link, use this command to fix it, then repeat the above ln-s command: `sudo rm -rf /var/www/html`

10. Install Apache, Download and Extract Wordpress, and Configure them both:

    During the creation of each EC2 instance, we should use `user_data` scripts to declare the installation routine for wordpress, and Apache/Nginx.  Before this was automated, i had to SSH into the EC2 instance, to manually prepare the installation routine.

    Identifying the SSH endpoint (public ip on the right)

    ![public ip](<./10-wp-pip.png>)

    Some of the commands given during the class on this topic, were missing command-line arguments (switches) to silcence the install routines. Thus i took it upon myself to define the entire shell script; here are the commands I manually entered in an SSH console:

    ```bash
    #!/bin/bash
    # Update the OS
    sudo apt-get update -y

    # Install Apache, PHP and a series of add-ins
    sudo apt install --yes php php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip php-mysql apache2
    
    # Disable the default site
    sudo a2dissite 000-default

    # Download wordpress latest, extract and copy out
    sudo wget --progress=bar:force:noscroll https://wordpress.org/latest.tar.gz
    sudo tar -xzf latest.tar.gz 
    sudo cp -r ./wordpress/* /var/www/html/
    sudo rm -rf ./wordpress ./latest.tar.gz

    # Configure Apache for wordpress
    sudo wget --progress=bar:force:noscroll https://raw.githubusercontent.com/sjackson0109/aws-solutions-architect/main/Project%200/Method%200%20-%20terraform/wordpress.conf
    sudo cp wordpress.conf /etc/apache2/sites-available/wordpress.conf
    sudo rm wordpress.conf
    sudo a2ensite wordpress

    sudo cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

    # Hardening wordpress
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
    ```

    Check the mount point is working:

    ![Mount Point Files](<./10-mount-point-files.png>)

11. Configure Wordpress database-connection string, and a handful of other items, using SSH scripts:

    Note the credentials below have long expired.

    ```bash
    #!/bin/bash
    # Declare associative array with configuration values
    DOMAINNAME="mydomain.com"

    DB_HOST="wordpress.c3flosirewfe.us-east-1.rds.amazonaws.com"
    DB_NAME="wordpress"
    DB_USER="wordpress"
    DB_PASS="98wZoV&=:?n\$[1Vn"
    DB_CHARSET="utf8"

    # Update wp-config.php file with database details
    WP_CONFIG="/var/www/html/wp-config.php"
    sed 's|database_name_here|'"${DB_NAME}"'|g' <<< $WP_CONFIG;
    sed 's|username_here|'"${DB_USER}"'|g' <<< $WP_CONFIG;
    sed 's|password_here|'"${DB_PASS}"'|g' <<< $WP_CONFIG;
    sed 's|localhost|'"${DB_HOSTNAME}"'|g' <<< $WP_CONFIG;

    # Fetch salts from WordPress API
    SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)

    # Remove existing salts in wp-config.php with the fetched ones appended to the bottom
    sed -i "/put your unique phrase here/d" $WP_CONFIG;
    echo "$SALT" >> $WP_CONFIG

    # configure the apache site binding
    sudo sed -i 's|{{ DOMAINNAME }}|'"$DOMAINNAME"'|g' /etc/apache2/sites-available/wordpress.conf

    # Restart Apache
    sudo systemctl restart apache2
    ```

    Visiting the page, to instigate configuration

    ![install](<../Method 1 - aws gui/11-wp-init.png>)

    Completing the setup:

    ![setup](<../Method 1 - aws gui/11-wp-setup.png>)

    After saving, the sql service is populated with a database schema, table designs, and a few sample records (hello world article, and of course my `sjackson` user):

    ![started](<../Method 1 - aws gui/11-wp-success.png>)

    Logging in for the first-time:

    ![wp welcome](<../Method 1 - aws gui/11-wp-welcome.png>)

12. Clone the EC2 Instance to a AIM image, and a template to use with cloud-formation later:

    ![aim image](<../Method 1 - aws gui/12-aim-image.png>)

    Create a launch instance template, and ensure the AIM is linked to the one `owned by me`. Attach the key-pair, subnet and frontend security group

    ![networking](<../Method 1 - aws gui/12-template-network.png>)


13. Test Launching multiple instances.
    
      - For now deploy two, ensure auto-assign an elastic ip is enabled.
        ```powershell
        aws ec2 run-instances --image-id <ami-template-image-id> --count 1 --instance-type t2.micro --key-name sjackson --security-group-ids <frontend-sg-id> --subnet-id <subnet-id> --user-data file://user_data.sh --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=wordpress-0}]' --block-device-mappings "[{\"DeviceName\":\"/dev/sdh\",\"Ebs\":{\"VolumeSize\":20,\"VolumeType\":\"gp2\",\"DeleteOnTermination\":false}}]"

        aws ec2 run-instances --image-id <ami-template-image-id> --count 1 --instance-type t2.micro --key-name sjackson --security-group-ids <frontend-sg-id> --subnet-id <subnet-id> --user-data file://user_data.sh --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=wordpress-1}]' --block-device-mappings "[{\"DeviceName\":\"/dev/sdh\",\"Ebs\":{\"VolumeSize\":20,\"VolumeType\":\"gp2\",\"DeleteOnTermination\":false}}]"
        ```

14. Testing SSH on the template-deployed instance, and access the web interface:
    
    ![testing ssh](<../Method 1 - aws gui/14-testing-ssh.png>)

15. Setting up Route53 Health Checks - confirming services are coming online.
    
      - Create health checks:
        ```powershell
        aws route53 create-health-check --caller-reference "health-check-1" \
        --health-check-config "IPAddress=<instance-public-IP>,Port=80,Type=HTTP,ResourcePath=/"
        ```

      - Create traffic policies, and attach to `mydomain.com`
        ```powershell
        aws route53 change-resource-record-sets \
            --hosted-zone-id <hosted-zone-id> \
            --change-batch '{
                "Changes": [{
                    "Action": "UPSERT",
                    "ResourceRecordSet": {
                        "Name": "mydomain.com",
                        "Type": "A",
                        "AliasTarget": {
                            "DNSName": "<elb-dns-name>",
                            "EvaluateTargetHealth": true,
                            "HostedZoneId": "Z2FDTNDATAQYW2" 
                        }
                    }
                }]
            }'
        ```
    The A record is answered by the traffic policy, and the www record is redirected to the A record. So whichever is requested by a client, should always get the answer from the traffic policy.
    
    ![traffic policy attached to root of zone](<../Method 1 - aws gui/15-r53-zone-view.png>)


      - Update the Traffic Policy to target the IP of the ELB instead of EC2 instances:
        ```powershell
        aws route53 change-resource-record-sets \
            --hosted-zone-id <hosted-zone-id> \
            --change-batch '{
                "Changes": [{
                    "Action": "UPSERT",
                    "ResourceRecordSet": {
                        "Name": "sjackson0109.click",
                        "Type": "A",
                        "AliasTarget": {
                            "DNSName": "<elb-dns-name>",
                            "EvaluateTargetHealth": true,
                            "HostedZoneId": "Z2FDTNDATAQYW2"
                        },
                        "HealthCheckId": "<health-check-id>",
                        "SetIdentifier": "sjackson0109.click"
                    }
                }]
            }'
        ```

16. Create 2x event bridge Schedules to stop and start the EC2 Instances.

      - Firstly, we need an IAM Polciy with an IAM role attached:

        ```powershell
        aws iam create-policy --policy-name EC2StartStopPolicy --policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "ec2:StartInstances",
                        "ec2:StopInstances"
                    ],
                    "Resource": "*"
                },
                {
                    "Effect": "Allow",
                    "Action": [
                        "logs:CreateLogGroup",
                        "logs:CreateLogStream",
                        "logs:PutLogEvents"
                    ],
                    "Resource": "arn:aws:logs:*:*:*"
                }
            ]
        }'
        ```

      - Then create the IAM role, and attach the policy:
        ```powershell
        aws iam create-role --role-name EC2StartStopRole --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": {
            "Effect": "Allow",
            "Principal": {
            "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
        }'
        aws iam attach-role-policy --policy-arn arn:aws:iam::<account-id>:policy/EC2StartStopPolicy --role-name EC2StartStopRole
        ```


      - With the following CRON schedules attached start `0 9 ? * 2-6 *` and stop `30 23 ? * 1-7 *`, we end up with:
        Stopping:
        ```powershell
        aws lambda create-function --function-name StopEC2Instances \
            --runtime python3.9 \
            --role arn:aws:iam::<account-id>:role/EC2StartStopRole \
            --handler stop-ec2-instances.lambda_handler \
            --zip-file fileb://stop-ec2-instances.zip
        ```
    
        Starting:
        ```powershell
        aws lambda create-function --function-name StartEC2Instances \
            --runtime python3.9 \
            --role arn:aws:iam::<account-id>:role/EC2StartStopRole \
            --handler start-ec2-instances.lambda_handler \
            --zip-file fileb://start-ec2-instances.zip
        ```

      - OR as event-bridge schedules instead (might be deemed more reliable):
        ```powershell
        # Start Schedule
        aws events put-rule \
            --name "StartEC2Instances" \
            --schedule-expression "cron(0 9 ? * 2-6 *)" \
            --state "ENABLED" \
            --description "Start EC2 instances every weekday (Monday to Friday) at 9:00 AM"

        aws events put-targets \
            --rule "StartEC2Instances" \
            --targets "Id"="1","Arn"="arn:aws:lambda:<region>:<account-id>:function:StartEC2Instances"

        # Stop Schedule
        aws events put-rule \
            --name "StopEC2Instances" \
            --schedule-expression "cron(30 23 ? * 1-7 *)" \
            --state "ENABLED" \
            --description "Stop EC2 instances every day at 11:30 PM"

        aws events put-targets \
            --rule "StopEC2Instances" \
            --targets "Id"="1","Arn"="arn:aws:lambda:<region>:<account-id>:function:StopEC2Instances"
        ```

    

17. Quick test with public DNS

    NOTE: for the purposes of this lab, i've not got adminsitrative access over the chosen domain-name, so i added 2x static A-record entries in my windows hosts file.
    
    ![final call](<../Method 1 - aws gui/17-final-http-call.png>)