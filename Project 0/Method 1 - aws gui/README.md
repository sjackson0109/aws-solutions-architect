## Note to the reader

The steps described below are to satisfy the tasklist identified for [Project 0](../README.md) in the parent folder.

## Step-by-step Instructions (GUI)
0. Start the AWS LAB, and login:

     ![Login](<../images/00-Login.png>)

1. Navigate to the VPC area, and Create a VPC:

    Specifics:- 
     2x availability zones, 2x public subnets, 2x private subnets, and 1 NATGW per-AZ.

    Create a VPC, with name:`wordpress-vpc`, base-cidr:`10.101.0.0/16`

    ![VPC](<../images/01-vpc-create.png>)

    Create 2x Public facing subnets, in two different Availability Zones
    ![Public Subnets](<../images/01-vpc-private-subnets.png>)

    Create 2x Private subnets, in two different Availability Zones
    ![Private Subnets](<../images/01-vpc-private-subnets.png>)

    Associate the Private subnets are associated with the correct route-table:
    ![RT Association](<../images/01-vpc-private-subnets-association.png>)

    Resource Map:

    ![Resource Map](<../images/01-vpc-resource-map.png>)

2. Search for `Key Pairs`. Create a key-pair.

    Specifics: Key-Type=`RSA`, Private Key Out: `ppk format`

    ![Key Pairs](<../images/02-key-pair.png>)

3. Search for Security Groups, Create:
    
    FRONTEND | public-sg:-
      -  Ingress: HTTP/S, SSH
         ![Frontend Ingress](<../images/03-sg-fe-ingress.png>)

      -  Egress: NTP, DNS, HTTP/S, MYSQL(10.101.0.0/16)
         ![Frontend Ingress](<../images/03-sg-fe-egress.png>)
         
    BACKEND | private-sg:-
      -  Ingress: MySQL:tcp/3306 only
         ![Backend Ingress](<../images/03-sg-be-ingress.png>)

      -  Egress: All Traffic (default)

4. Create an Internet Gateway and attach it to the VPC
   
    Create and Attach an Internet Gateway to the VPC:
    ![IGW](<../images/04-vpc-attach-igw.png>)

5. Create an RDS CLUSTER

    Specifics: Aurora/MySQL mysql 8.0 compatible, serverless, multi-availability-zone, ensure `wordpress-vpc` selected, ipv4 only, use existing security group `backend-sg`
 
    Creating the Cluster
    
    ![Create RDS Cluster](<../images/05-rds-1-create.png>)

    Specify the DB Engine (Default)

    ![DB Engine](<../images/05-rds-2-engine.png>)


    Capture the username and password: `u2PcCz8Z5pj5`

    ![Admin PWD](<../images/05-rds-3-admin.png>)


    Specify serverless compute, with enough capacity to run the dev/test instance (2GB RAM x 2 container instances)

    ![Serverless](<../images/05-rds-4-serverless.png>)


    Specify Multi-Availability-Zone

    ![Multi-AZ](<../images/05-rds-5-multi-az.png>)

    Attach to the existing vpc called `wordpress-vpc`

    ![VPC](<../images/05-rds-6-vpc.png>)

    Create a new DB Subnet Group

    ![New Subnet Group](<../images/05-rds-7-create-db-subnet-group.png>)

    Attach the existing security-group called `backend-sg`

    ![Existing SG](<../images/05-rds-8-existing-sg.png>)


    Short Summary:

    ![Overall Creation](<../images/05-rds-setup.png>)

    RDS Instance must have nightly maintenance, including a backup routing:

    ![Backup Status](<../images/05-rds-backup-status.png>)

6. Create an Elastic File System
   
   This is to be used as a data-disk for each EC2 Instance late; however needs creating and then associating with the VPC first:

    ![EFS Creation](<../images/06-efs-create.png>)

7. Create EC2 Instance
   
   Specify: OS=`Ubuntu LTS`, CPU Arch=`x64`, Instance-Type=`t2.micro`, network=`wordpress-vpc`, subnet=`pub-us-east-1a`, Security Group=`frontend-sg`, FileSystem=`wordpress-data` mounted to `/mnt/efs/data`

    Label the EC2 instance

    ![VM Name](images/07-ec2-name.png)

    Select the AIM image `Ubuntu`, with `x64` based architecture

    ![EC2-OS](images/07-ec2-os.png)

    Ensure the EC2 Instance-Type is `t2.micro`, we don't need any larger a compute instance

    ![EC2-TYPE](images/07-ec2-type.png)

    Select the appropriate key-pair for SSH based administration

    ![EC2-Keys]](images/07-ec2-key-pair.png)

    Ensure the `wordpress-vpc` is used, and attach to the `pub-us-east-1a` subnet

    ![EC2-NIC](images/07-ec2-core-network.png)

    Associate with the Security Group `frontend-sg`:

    ![EC2-SG1](images/07-ec2-backend-sg.png)
    
    HUMAN ERROR: I made a mistake here, accidentally mounting the `backend-sg` rather than the `frontend-sg`; so here is the update operation: 

    ![EC2-SG2](images/07-ec2-frontend-sg-update.png)

    Mount the encrypted file-system `wordpress-data` to a local path `/mnt/efs/data`

    ![EFS Mount](images/07-ec2-efs-mount.png)

8. Prepare the Wordpress database
   
    SSH into the wordpress instance using the public IP address, or EC2 Console.
    
    ![View Public IP](images/10-wp-pip.png)

    Verify network connectivity to the RDS database instance. 
    
    ![Network Connection to RDS](images/08-confirm-network-connectivity-to-db.png)

    Execute the command `sudo apt install --yes mysql-client-core-8.0` so that we can actually login to RDS with a mysql client. Login using `mysql -h <RDS ENDPOINT NAME> -u rds_user` with the password setup earlier. Create the both the `Wordpress` Database and Username, followed by `Grant all privileges`, `flushing privileges` at the end. 

    ![Create Wordpress DB](images/08-create-wp-db.png)

    NOTE: I repeated this command using the suffix `with grant option;`. After confirming all the necessary commands, i've subsequently extracted this to a `user_data` first-boot-script for my future EC2 instances.
   
9. Prepare the EFS Sym-links, if not already automated.

    Simply execute the `sudo ln -s /mnt/efs/data/html /var/www/html` command:
    
    ![Sym Links](images/09-sym-links-to-efs-disk.png)

    Note: if Apache was installed before executing this command, there is an error creating the target html link, use this command to fix it, then repeat the above ln-s command: `sudo rm -rf /var/www/html`



10. Install Apache, Download and Extract Wordpress, and Configure them both:

    During the creation of each EC2 instance, we should use `user_data` scripts to declare the installation routine for wordpress, and Apache/Nginx.  Before this was automated, i had to SSH into the EC2 instance, to manually prepare the installation routine.

    Identifying the SSH endpoint (public ip on the right)

    ![public ip](images/10-wp-pip.png)

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

    ![Mount Point Files](images/10-mount-point-files.png)

12. Configure Wordpress database-connection string, and a handful of other items, using SSH scripts:

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

    ![install](images/10-wp-init.png)

    Completing the setup:

    ![setup](images/10-wp-setup.png)

    After saving, the sql service is populated with a database schema, table designs, and a few sample records (hello world article, and of course my `sjackson` user):

    ![started](images/10-wp-success.png)

    Logging in for the first-time:

    ![wp welcome](images/10-wp-welcome.png)

13. Clone the EC2 Instance to a AIM image, and a template to use with cloud-formation later:

    ![aim image](images/13-aim-image.png)

    Create a launch instance template, and ensure the AIM is linked to the one `owned by me`. Attach the key-pair, subnet and frontend security group

    ![networking](images/13-template-network.png)


14. Test Launching multiple instances.
    
    For now deploy two, ensure auto-assign an elastic ip is enabled.
    
    ![launch](images/14-launch.png)

15. Testing SSH on the template-deployed instance, and access the web interface:
    
    ![testing ssh](images/15-testing-ssh.png)

16. Setting up Route53 Health Checks - confirming services are coming online.
    
    ![r53 health checks](images/16-r53-health-checks.png)

    Create traffic policies, and attach to `mydomain.com`

    ![traffic policies](images/16-r53-traffic-policy.png)


    The A record is answered by the traffic policy, and the www record is redirected to the A record. So whichever is requested by a client, should always get the answer from the traffic policy.
    ![traffic policy attached to root of zone](images/16-r53-zone-view.png)


17. Create 2x event bridge Schedules to stop and start the EC2 Instances.

    Firstly, we need an IAM Polciy with an IAM role attached:

    ![iam policy](images/17-iam-policy.png)

    ![iam role](images/17-iam-role.png)

    Then we need to create two event-bridge schedules, to stop and start the ec2 instances.

    ![alt text](images/17-em-schedules.png)

    With the following CRON schedules attached start `0 9 ? * 2-6 *` and stop `30 23 ? * 1-7 *`, we end up with:

    Stopping:

    ![stopping](images/17-em-stop-dates.png)

    Starting:

    ![starting](images/17-em-start-dates.png)

18. Quick test with public DNS

    NOTE: for the purposes of this lab, i've not got adminsitrative access over the chosen domain-name, so i added 2x static A-record entries in my windows hosts file.

    
    ![final call](images/18-final-http-call.png)