# Building-Highly-Available-Web-Application
Playroom On-Prem is moving it's web operation to the AWS Cloud and wants a working prototype that would be fast, durable, scalable and more cost-effective than the current on-prem setup

## Objective
After completing this project, you will be able to:
- Deploy a virtual nrtwork spread accross multiple availability zones.
- Create a highly available and fully managed database cluster using Amazon RDS.
- Create a database caching layer using Amazon ElastiCache.
- Use Amazon Elastic File system (Amazon EFS) to provide a shared storage layer across multiple Availability Zones for the Application layer.
- Deploy a highly available web application using Amazon EC2 Auto Scaling and Elastic Load Balancing.


## Architecture Diagram
![Architecture Diagram](./Assets/hawa-overview.png)


## AWS Services Used
- A single AWS Region with one VPC spanning multiple Availability Zones.
- Each Availability Zone will have both public subnets, an app subnet, and a database subnet.
- An Internet Gateway attached to the VPC to allow communication between the public subnets and the internet.
- A NAT Gateway in each public subnet to allow instances in the private subnets to access the internet.
- An Application Load Balancer and an Auto Scaling group that has app servers in the app subnets for both Availability Zones.
- Each app server will mount an EFS file system to provide a shared storage layer.
- All App servers communicate with an Aurora primary DB instance in one of the databasee subnets. The other database subnets holds an Aurora read replica for high availability.
- An ElastiCache cluster in one of the database subnets to provide a caching layer for the application.

## Pricing
There would be costs associated with the resources used in this project.

## Author
- D-Cyberguy (Cloud Security Engineer)


