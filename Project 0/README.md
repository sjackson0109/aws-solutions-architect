## Preface

Author: Simon Jackson (sjackson0109)

Date: 10/02/2024

## Real-world relevant scenario
This is a relevant real-world scenario, as plenty of companies need to make use of Wordpress.

## Objective
To set up and monitor a WordPress instance for your organisation inside AWS, using Cloud Formation.

## Refined milestones
- Launch both EC2 and RDS instances using AWS CloudFormation
- Configure RDS with Backup and Maintenance lifecycles
- (optional) Confirm RDS Instances is configured for Multi-AZ
- Setup EC2 Instances, with user_data one-time boot scripts, to configure NginX
- ... install the Wordpress Frontend and configure it's database connection
- Limit the flow of traffic using Security Groups
- Attach a domain using Route53
- Monitor each EC2 instance using Route53 Health Checks
- (optional) Trigger DNS Traffic-Flow Policies based on the status of Health Checks (or use ALB)
- (optional) Configure the Elastic Load Balancer to distribute client traffic to each ec2 instance, use session-persistant options  (or use Traffic-Flow Policies)
- Configure nginx error document handling, saving to an S3 bucket
- Set up a duplicate WordPress instance (to be used for development/testing), ensure this will only be available only for business hours (M-F 9 AM–6 PM)

## Decision Tree
-   **A default VPC with subnets already exists, will we use our own? YES**

    By delivering our own VPC with 4x Subnets - we meet the objective of an isolated environment, knowing exactly what resources are attached to our VPC.
    
    The VPC will have a CIDR of 10.101.0.0/16

    2x subnets in each region, and one subnet in each region public facing. 
    - pub-us-east-1a (10.101.0.0/24)
    - pub-us-east-1b (10.101.1.0/24)
    - priv-us-east-2a (10.101.2.0/24)
    - priv-us-east-2b (10.101.3.0/24)

-   **Do we need an Internet Gateway? YES**
    
    Routing traffic into/out of the public-facing front-end requires an internet gateway.

-   **Do we need Elastic IP Addresses on our EC2 Instances? YES**

    We need Elastic IP Addresses for remote administration (SSH) to each EC2 Instance, and to expose the web-frontend over HTTP/S (tcp/80 or tcp/443).

-   **Are we registering a DNS Zone? YES**

    To avoid the added complexity, or unnecessary cost, of an elastic load balancer; we can simply rely on Route 53 Health Checks, through a traffic-flow policy, to route clients to an active frontend. Thus this solution will be considered an `active/failover form of high-availability` only. 

-   **Are clients going to reach the front-end over the internet? YES**

    Simply targeting their web browser towards: http://www.mydomain.com.

-   **Are we going to use NAT Gateways, one per public facing subnet? NO**

    If we were to Proxy, or Load Balance the ingress WAN traffic, then perhaps a NAT Gateway might make sense. For now this is not necessary.

-   **Are we going to register an SSL Certificate, on each EC2 instance?  No**

    We would need to automate the certificate renewal process to achieve this. Whilst this is possible with Certbot scripting, there are layers of complexity here that remain outside of the objectives of this project. Namely:
    
    {

    - ACME v1 HTTP calls, require file-system manipulation - to ensure ingress http calls reach the same file-system, we will need to use an Elastic File System, mounted on both EC2 instances, as the data are for our wordpress installation.  
    
    -or-

    - ACME v2 requires the establishment of IAM users, with API keys, IAM policies granting delegate access to the DNS Zone. ACME v2 would be a preferred method.

    }
    
    -and-
    
    {

    - Output PEM/CER files would need to be accessible on both EC2 instances - another advocator for EFS. Yet the Private Key should be stored securely; but readable by Apache/Nginx.
    
    }

-   **Are we using an RDS Instance? YES**

    We will manually deploy an RDS Cluster, configured for Multi-AZ.
    
    This cluster will require the 2x Private subnets to be added into a Database Security Group.

    The cluster should have 2 instances running, one in each region/subnet.

    A single database-instance called "wordpress" should be registered 

-   **Are we blocking TCP/UDP ports where necessary? YES**

    Inspite the EC2 Instances will likely only be listening on certain TCP ports; it's always a good idea to control Ingress and Egress traffic. Rules will include:
 
    - Ingress SSH (TCP/22) from my home public IP allowed to reach the Public facing subnets (changes daily, so am not fussed in publishing it).
    
    - Ingress HTTP (TCP/80) and HTTPS (TCP/443) from any source, targeting the Public facing subnet.

    - Egress MySQL (TCP/3306) from the front-end subnets, to the back-end subnets. This rule needs duplicating on the frontend-security-group and the backend-security-group.

-   **Are we going to use user_data scripts to automate the installation of wordpress? YES**

    USER_DATA scripts are useful for first-time-boot, only.
    
    Thus, manually installing wordpress-frontend, and then extracting the history from the bash `history` command, would be an easy way to prepare a valid user_data script. The EC2 instance can then have the user_data updated; and finally we can convert this EC2 disk into a new AIM image.

    We can then consider creating scale out the EC2 instance, with deployed copies of this AIM template disk.


## Intended Architecture
[![](https://mermaid.ink/img/pako:eNrVWnuPozgS_yqI-TekCZDn7o7Ur5xGmpVmp1da6bZXLWM7xApgxjZJZ0bz3a_MKyFJgzPaO90SdQvsKtv1-FWVDd9szAm1F3YkULa2fn94Ti24CBMUK8ZT6_e757RswzGS8oGuLEJXKI-VhXnMxeKd67oDqQTf0IUSKJUZEjRVP50woa81_djVv8GKxfExQz3GO0zIOETVo7NjRK0XXvZaNxAk10gItF9MTucgqbSKYd9hj7p40gw5miB3Nh7ELKXOmrJorRajWfZ6yp_lYcxwNcQ8HM_DwxAzGgSIDEoZOuTMBNsiRatB_CCYj2kziId9CqL3DkJCGR2r901dLcezsT_5EV2tGSE0NZnkuClDhLA0WrgwR4JExFJ9e2ZrnFTyL5fz-cE93vm-f0a7qm22nN97rtdJyyrScXAX-ONO0jishz1W0WXajEVgsh3aVyyue-cvg26WLKFy3dCPH2_HPfQiT1MqGr0E09FtJ4da0xRV5LOl_zh_7CTPFZcYgYdHFc9j4N-OOhcVUtTYaTr3u9cT5iSiqrHV8t7ttiuOeU7mFXng618v-YqLBBVRpxL7fj7uFrtkEzxVjbX1r5dFUiTw2tibCh7AAYvr4FBcvSw7pJpZ-v1QR-IwZzGptQZKnj30cWCeJKwRHyKr7_WxEJrFfG9ses2SsYzq8FnHNbiWyz4mqZC4YpYoZYrX9A93M2_aTZ-uWGQcO3Au4gaubo_zEqTQicT9vqiZ5D6t84f_MJ9Pe2Z5NfYNPXiIpLn-SSLNV84xqcNl4I5ns87YR6RxmCT7FCX8irFpaJ4NKPasNxMj0B8lqEHIBaGiuG3lSt1wlNPOp5DGiYzWiezSclar1Rk9yyyDlHvGBjeKYYTX1NjRKh6I9ylAMt4YY7JibEXL_mRHE2GMYrqR5uNeQboF1YWCQc4ydtYV1Lxr3kCsH5OQrigGBZnPIM0BH8UIs6ZeuHf1r5uehwh4MI2pQIoLYxxFORKE5KpOCNNguuxOO3XYvc5zGXTApoKbOwfjyjhyAC1KUbzX7mosOjAVniKvWZJaQ7SQ5X7JFEgbtNogY-_dQNqRTBr7SkV_vfwV45YRap54Y7Shp5Vav-_HKAkJMlYY7MNoKmkCMkUNCvozWaJBY1xjQ4LYUJUBaqixnx3xJFRRoQtuScUW1muivIQShqB0SQEJxvatmbZUmAebgilmW2rsDQVHhvAGHUXNPl8tmCSg2jwdHVgcXdYY71cKPgVF-CGEGKgu4WLfVCAG8jBAtvbsdR6aux0PWUyNEZR8MV5_SjOVX1F2p1TtuNi0cdNvep5JzSaN8VkzNDv9fofkIkIp-1oo17w2_RIT8538l5zhjdTnO8b2Fk05e67cv6GCFJTINVspYycXdFNshA6xtd-fBJU8F5hGgueZefRvRDesWGF0Rce-sTUqesITxFLzTUPFpoWKt40P91tS-sZBXPoQTaE7NtaV9GFVGZfKPCtLQGACuVL8OEev5SXFgip5Avf-iSBhURFTKfXBFM24sXGqVIchDsc8MkaxfLtihDw9ngLWDieRZ8xrRptDkX4EAf7TK0KfTMy3FTLlO6iyY3P7SG5uFMiIYMX2UWT_2dTBJfsPpWQeQoKwVjFHagEFFtQvg9MTYI38v-F8WeZZxptyxcAMu5Vx8lH0FRwJm9dChdthwULzHF2wxEcn-b1ljRI0zGFbbl7XbTNsdap_hoPViv6I-nVyJhyb51nNELN0YwyzIv1DtUjNE86rQJ2njiU5OGm5uQL1_PlswzwEYpSUDjw_23-VRG-9pNIXi4DtZ5ZAYS7wL8_2WqlMLm5uJKiL0mHEFNR2Q8Zv0E46chs5DLKBvLkVeM0UjJhDYfpUxjnng-56cae-C7KNCpqXpxKoN8GsfL7948mp2px_leh9CWZDGPnZBnjuY6oXUb52CorXTrZ18_6DRh-g8edQvK-42tKlUku_2w2TfZlCh5gnpySW4zj6KGl0sdU7tGqaP69XyueqtDhVBLS_3PMkg1Rd3Aezl49awOLhNkFfeeo83nsvj-UJkvPhk3NLiDZjQ9qnoIrV-vAJ_aUFeq9P_EYtibx_qkThQSLv2HUb35eRU76NBB_4VL6W1I5y6c_6o0aItdRvQmhKWl7ShsrHz-2eZsZyOieXDoVVOiMEMx8eTicducOROxq6Q_fGC86mK8wDxvrv4rC21iSocHgw0iTotcW9h87WrVVnpp3wWDvhG9oZdWrH-__WTtitneLhguPSFay2DIYg302SqhtoutEb_fMBV_J_E6lPdVBBeAmbdudpLxVNDHRiPS6fWiK09NFCbvkNgIZu9TXAW9gt8Pvr_um3j9YdwptL0G0GJqFT1m9Osc-D0U9aLjpaO0me9h78u1zolfD33nZwfcEG88dCQFeMfqjehL0ZpG9zAVavnz4_PDkf9GuPFFPjQG0BF7qM29MI0a1FozDh92rR-8dqMTTT4luh5eiWRTplQl3TpMaKBPJM0VO423HbsGjymibvApl3RNZMWo2o41Ob-dBS1LR6TSw6rnKL4gv-Wm269BroakXftXtgpkExOPxr96yKv9O2OrRWn--0urVcAy2Jvmv1nKX2wVk6q7aGbbazmDA4d_BLjCdxqficqUVwiJGDxprWCY3eHMEftNkDO6ECKmBiL-xv1rMN-9cdhp2PerYXlm7AudhS_fBsQzDPHnJ9LA8--P078OpPY572KbYXSuR0YOcZJCP6wBBgNrEXKxRLaM1Q-m_Ok5oIHu3FN_vVXozc6XDuzkf6q7WZNwqm44G9txeT4XQymbsT13eDYB6MvO8D-2sxAGT94vL8WTCajafzgU0JA7v9Wn5pV3xw9_0_C2aIkg?type=png)](https://mermaid.live/edit#pako:eNrVWnuPozgS_yqI-TekCZDn7o7Ur5xGmpVmp1da6bZXLWM7xApgxjZJZ0bz3a_MKyFJgzPaO90SdQvsKtv1-FWVDd9szAm1F3YkULa2fn94Ti24CBMUK8ZT6_e757RswzGS8oGuLEJXKI-VhXnMxeKd67oDqQTf0IUSKJUZEjRVP50woa81_djVv8GKxfExQz3GO0zIOETVo7NjRK0XXvZaNxAk10gItF9MTucgqbSKYd9hj7p40gw5miB3Nh7ELKXOmrJorRajWfZ6yp_lYcxwNcQ8HM_DwxAzGgSIDEoZOuTMBNsiRatB_CCYj2kziId9CqL3DkJCGR2r901dLcezsT_5EV2tGSE0NZnkuClDhLA0WrgwR4JExFJ9e2ZrnFTyL5fz-cE93vm-f0a7qm22nN97rtdJyyrScXAX-ONO0jishz1W0WXajEVgsh3aVyyue-cvg26WLKFy3dCPH2_HPfQiT1MqGr0E09FtJ4da0xRV5LOl_zh_7CTPFZcYgYdHFc9j4N-OOhcVUtTYaTr3u9cT5iSiqrHV8t7ttiuOeU7mFXng618v-YqLBBVRpxL7fj7uFrtkEzxVjbX1r5dFUiTw2tibCh7AAYvr4FBcvSw7pJpZ-v1QR-IwZzGptQZKnj30cWCeJKwRHyKr7_WxEJrFfG9ses2SsYzq8FnHNbiWyz4mqZC4YpYoZYrX9A93M2_aTZ-uWGQcO3Au4gaubo_zEqTQicT9vqiZ5D6t84f_MJ9Pe2Z5NfYNPXiIpLn-SSLNV84xqcNl4I5ns87YR6RxmCT7FCX8irFpaJ4NKPasNxMj0B8lqEHIBaGiuG3lSt1wlNPOp5DGiYzWiezSclar1Rk9yyyDlHvGBjeKYYTX1NjRKh6I9ylAMt4YY7JibEXL_mRHE2GMYrqR5uNeQboF1YWCQc4ydtYV1Lxr3kCsH5OQrigGBZnPIM0BH8UIs6ZeuHf1r5uehwh4MI2pQIoLYxxFORKE5KpOCNNguuxOO3XYvc5zGXTApoKbOwfjyjhyAC1KUbzX7mosOjAVniKvWZJaQ7SQ5X7JFEgbtNogY-_dQNqRTBr7SkV_vfwV45YRap54Y7Shp5Vav-_HKAkJMlYY7MNoKmkCMkUNCvozWaJBY1xjQ4LYUJUBaqixnx3xJFRRoQtuScUW1muivIQShqB0SQEJxvatmbZUmAebgilmW2rsDQVHhvAGHUXNPl8tmCSg2jwdHVgcXdYY71cKPgVF-CGEGKgu4WLfVCAG8jBAtvbsdR6aux0PWUyNEZR8MV5_SjOVX1F2p1TtuNi0cdNvep5JzSaN8VkzNDv9fofkIkIp-1oo17w2_RIT8538l5zhjdTnO8b2Fk05e67cv6GCFJTINVspYycXdFNshA6xtd-fBJU8F5hGgueZefRvRDesWGF0Rce-sTUqesITxFLzTUPFpoWKt40P91tS-sZBXPoQTaE7NtaV9GFVGZfKPCtLQGACuVL8OEev5SXFgip5Avf-iSBhURFTKfXBFM24sXGqVIchDsc8MkaxfLtihDw9ngLWDieRZ8xrRptDkX4EAf7TK0KfTMy3FTLlO6iyY3P7SG5uFMiIYMX2UWT_2dTBJfsPpWQeQoKwVjFHagEFFtQvg9MTYI38v-F8WeZZxptyxcAMu5Vx8lH0FRwJm9dChdthwULzHF2wxEcn-b1ljRI0zGFbbl7XbTNsdap_hoPViv6I-nVyJhyb51nNELN0YwyzIv1DtUjNE86rQJ2njiU5OGm5uQL1_PlswzwEYpSUDjw_23-VRG-9pNIXi4DtZ5ZAYS7wL8_2WqlMLm5uJKiL0mHEFNR2Q8Zv0E46chs5DLKBvLkVeM0UjJhDYfpUxjnng-56cae-C7KNCpqXpxKoN8GsfL7948mp2px_leh9CWZDGPnZBnjuY6oXUb52CorXTrZ18_6DRh-g8edQvK-42tKlUku_2w2TfZlCh5gnpySW4zj6KGl0sdU7tGqaP69XyueqtDhVBLS_3PMkg1Rd3Aezl49awOLhNkFfeeo83nsvj-UJkvPhk3NLiDZjQ9qnoIrV-vAJ_aUFeq9P_EYtibx_qkThQSLv2HUb35eRU76NBB_4VL6W1I5y6c_6o0aItdRvQmhKWl7ShsrHz-2eZsZyOieXDoVVOiMEMx8eTicducOROxq6Q_fGC86mK8wDxvrv4rC21iSocHgw0iTotcW9h87WrVVnpp3wWDvhG9oZdWrH-__WTtitneLhguPSFay2DIYg302SqhtoutEb_fMBV_J_E6lPdVBBeAmbdudpLxVNDHRiPS6fWiK09NFCbvkNgIZu9TXAW9gt8Pvr_um3j9YdwptL0G0GJqFT1m9Osc-D0U9aLjpaO0me9h78u1zolfD33nZwfcEG88dCQFeMfqjehL0ZpG9zAVavnz4_PDkf9GuPFFPjQG0BF7qM29MI0a1FozDh92rR-8dqMTTT4luh5eiWRTplQl3TpMaKBPJM0VO423HbsGjymibvApl3RNZMWo2o41Ob-dBS1LR6TSw6rnKL4gv-Wm269BroakXftXtgpkExOPxr96yKv9O2OrRWn--0urVcAy2Jvmv1nKX2wVk6q7aGbbazmDA4d_BLjCdxqficqUVwiJGDxprWCY3eHMEftNkDO6ECKmBiL-xv1rMN-9cdhp2PerYXlm7AudhS_fBsQzDPHnJ9LA8--P078OpPY572KbYXSuR0YOcZJCP6wBBgNrEXKxRLaM1Q-m_Ok5oIHu3FN_vVXozc6XDuzkf6q7WZNwqm44G9txeT4XQymbsT13eDYB6MvO8D-2sxAGT94vL8WTCajafzgU0JA7v9Wn5pV3xw9_0_C2aIkg)


## Tasklist
1. Create the VPC with Subnets
2. Create Key Pairs
3. Create the Security Groups, ensure these are attached to the respective subnets
4. Create a Internet Gateway (if not included with the VPC)
5. Create an RDS Cluster, with instances in each-az, and two subnets in the db-subnet-group, include 1x database called `wordpress`. Configure Cluster scaling, so we always have a replica
6. Create an Elastic File System, configure an archive policy.
7. Create 1x EC2 instance, with Ubuntu on, dev/test, containers, select vpc, select/create SG, select EFS (/mnt/sfs/data)   
8. SSH in and configure the VM for Apache/Nginx, PHP
9. Connect to RDS, and create a `wordpress` database, with a admin credential.
   Create another `wordpress` user and grant access to the `wordpress` database and schema.
10. Install Apache, Download and Extract Wordpress, and Configure them both
11. Configure a `wp-config.php` file with the necessary database-connection-string; including starting the web-service, and register the web-service to run on machine start-up
12. Conver the EC2 Instance to an AIM disk-image
13. Deploy 2 copies of this template, into each public-facing subnet
14. Configure Route53 Health Checks, against each public IP 0 confirm the state of each health check
15. Demonstrate availability of each ec2 instance, inline with the health check
16. Setup a Route53 Traffic Flow policy, to distribute the web traffic to the live/healthy nodes
17. Use AWS Instance Scheduler to STOP both instances after 11:30pm;and start again at 9:00am

## Step-by-step Instructions (using terraform)
The terraform instructions can be found [here](<./Method 0 - terraform/README.md>)

## Step-by-step Instructions (aws console)
The terraform instructions can be found [here](<./Method 1 - aws console/README.md>)



## Challange an engineer, question time:
1. What is the primary goal or objective of deploying this infrastructure on AWS?

    The purpose is a hosted platform, potentially demonstrating a real-world scenario, and giving practical experiences to deploying a highly-available platform in a lab, ahead of having to do similar infront of a customer, under tight project deadlines.

2. How do you plan to handle scalability and performance requirements for the deployed resources?

    The RDS cluster will scale, using a scaling configuration, and the EC2 frontend instance, will be templated, and multiple frontends will be deployed.
    It's entirely possible to attach a cloud-formation routine to scale-up/down based on customer load; this requires a elastic-load-balancer. This is potentially out of scope of this project, as we are using dns to deliver traffic to the active frontend.

3.  What security measures are implemented in the infrastructure setup, especially regarding access controls and data encryption?

    Disk encryption is enabled; i've opted for a http connection to the web-frontend, purely for the demonstration of the service-ha. Having delivered highly secure web-services in my working career, with ssl certificates and web-server hardning techniques, i'm comfortable i could secure this platform if needed. I very much doubt that the security-stance is part of the measurable-objective of this course.

4. How do you intend to monitor the health and performance of the deployed resources, and what logging mechanisms are in place for troubleshooting?

    The initial availability monitoring will be provided using Route53 Health Checks.  SNS could be used for alerting, but won't be necessary for a lab exercise that only lives for up to 6 hours.

    In a real-world scenario it would be advisable to also include end-to-end product health monitoring, using cloud-watch, and ensure a clean audit history of changes, using cloud-trail. Web-server logs should be sent to an S3 bucket, with a retention/archive policy meeting compliance expectations.

5. Have you considered cost optimization strategies, such as leveraging AWS cost management tools or using reserved instances for cost savings?

    For the purpose of keeping costs low; i've opted for a serverless backend and low-spec ec2 instances for the frontend. All the bells and whistles (such as an rds proxy, or load balancer, ssl certificate manager, or ec2 compute scale-set) all seem unnecessary for a small wordpress website. 

    Cost-budgets are available and can be applied at the organisation level.

6. What strategies are in place for disaster recovery and data backup in case of unexpected incidents or failures?

    The MySQL DB is backed up daily, and able to be interactively restored/downloaded for alternative restore options.
    The EC2 instance configuration should be entirely on the Elastic File Storage mount-point.  A simply backup policy can be applied here, with a retention to clone files to an S3 bucket for longer-term storage if necessary. For now this is out of scope.

7. Are there any specific compliance requirements or regulations that the infrastructure setup needs to adhere to?

    Outlined in the course project task, this is not defined.  Having worked in industry where this is highly regulated, and changes all the time, i'm used to having a ticket-driven series of itterative changes/adjustments, which is the primary reason for choosing terraform, and for reducing repetative code-blocks.

8. To what extent is automation utilised in managing and deploying the infrastructure, and are there plans to further automate operational tasks?

    No plans to continue with this code beyond the submission of the coursework; however if someone wants to contribute, or provide feedback, i'd be willing to listen and support queries.

9. How is collaboration handled among team members for managing the Terraform codebase, especially in terms of version control and code review processes?

    All this terraform code is my own work. no team members contributed towards the project, code, solution design nor writeup.

10. Are there any planned enhancements or updates for the infrastructure setup, and how do you prioritize and manage these changes over time?

    It may be possible to fork this work for future customer engagements. but i'd personally like to consider the same project variable (tfvars) and scale the project code to support multi-cloud platform. Although i doubt time will allow for this.

11. Can you elaborate on the rationale behind choosing to deploy your own VPC with subnets instead of using the default VPC provided by AWS?

    Yes, quite simply i wanted a clearly defined set of subnets, with custom route-tables. It's not necessary, but it's a good practice to encorporate ALL the code for the entire infrastructure design in one place. I could have used a `data "aws_vpc"` item, but i would still be creating more subnets, subnet groups, security groups, route-tables, nat-gateways etc. didn't seem like much of a challange.

12. How do you plan to handle the setup and configuration of Nginx on the EC2 instances, especially considering the use of user_data scripts for automation?
    
    Initially, via SSH, ensuring all commands work. Then through user_data scripts, with variable substitution with terraform, then additional configuration performed with terraform null_reference remote-exec commands.

13. Could you explain the reasoning behind the decision not to use Elastic Load Balancers (ELB) and instead rely on Route 53 Health Checks for routing traffic to the active frontend?

    Yes, the project document privided by simplilearn clearly states to use route53 health checks. Implying that UP/DOWN event is the control point for a DNS query. Achievable with a simple route53 traffic-flow policy.

14. In terms of security, what measures are in place to ensure secure communication between the EC2 instances and the RDS database, particularly regarding network access controls?

    Private ip routing. Security Groups acting as a layer-5 firewall (allowing tcp/3306 only). and of course authentication into the mysql instance. Authentication details are passed in a TLS session with the aurora mysql  instance too.

15. How do you intend to manage and update the WordPress instances, including applying patches and updates to ensure security and stability?

    I was considering updating the installation of wordpress using terraform based null_reference remote-exec shell scripting to simply download, extract and copy to the elastic-file-share. Then all EC2 instances will instantly be able to use the same copy of the php code.

    As for plugins, that must be performed inside the wordpress/wp-admin area.

    Database environments can be upgraded, and the maintenance window will perform those upgrade operations.  Automatic minor-verion-updates is enabled.