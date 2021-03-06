# Deployment on AWS

[What we are building](../0-resources/AWS-3-tier-infra.png) 

## Resource referencing
Most Resources are referenced by id
ie. aws_vpc.my_vpc.id


<!--https://rancher.com/docs/k3s/latest/en/-->
1. Rancher K3s: lighter version of K8
2. 1 K3s control plane + 1 K3s node for master master replication
3. 2 K3s => connected to an ALB 
4. K3s nodes are in the public subnet because we want to avoid provisioning an NAT GW, but private sn is best practice
5. K3s allows for mySQL or postgresSQL which means we can use Amazon RDS
6. Amazon RDS instance in the private sn
7. Amazon RDS accessable through private route table
8. we also have an public route table deployed with TF techs: Dynamic Blocks, for Each etc.
9. VPC and IGW for internet traffic
10. "remote" ? provisioners for copying k3s.yaml files from the local machine (cloud9 node workspace machine) to k3s control node

## Using Terraform cloud to monitor state setup
1. have an TF account, create an organization
2. copy CLI-driven runs config into working dir, paste it in a tf file (backend.tf)
3. in cli: <tf login> and login with api
4.  In the tf organization general settings page, change from remote to local
    a. Your plans and applies occur on machines you control. Terraform Cloud is only used to store and synchronize state.
5. setup providers and region

## Setting up a AWS VPC
<!--https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc-->

## VPC DNS support provided settings 
Instance launched into the VPC receives a public DNS hostname 
if it is assigned a public IPv4 address or an Elastic IP address at creation. 
If you enable both attributes for a VPC that didn't previously have them both enabled, 
instances that were already launched into that VPC receive public DNS hostnames if they have a public IPv4 address or an Elastic IP address.

Attributes:
enable_dns_hostnames = true
enable_dns_support   = true

## Subnetting
Review for dividing networks
[Sunny's Video](https://www.youtube.com/watch?v=ecCuyq-Wprc) 
[Sunny's table](https://o.quizlet.com/1XQN.GACbk3TWNRitGHrfg.jpg) 
[Subnetting /16](https://www.youtube.com/watch?v=OQ-r_IfeB8c) 
[Practice](https://docs.google.com/spreadsheets/d/1U7h3xOY5FKOsHedjIOsJKQMobHrAHZcW9MCSxRyjVYE/edit#gid=0) 

Example:
1. if you need 3 subnetworks from the ip: 192.168.4.0/24
2. According to the table, we can split it into 4 subnets to satisfy the 3
3. We will have 64 host IDs (uniquely identifies a host on a given TCP/IP network)
4. 64 also includes the network and broadcast id 
5. /26 is the new subnet masks
6. Network id will be divided into [ _0/26, _64/26, _128/26, _192/26]
7. ie. 192.168.4.0/26 => Host ID Range: 192.168.1 - 192.168.4.62, #Hosts: 62, BroadcastID: _63

### Host vs. Network address
Host has a single IP address, and a network has several.
Example:
Host address for one of the servers here in my house is 
192.168. 1.249. It's a single address which is 
part of the network address block based on 192.168.

## cidrsubnet() function 
<!--https://www.terraform.io/language/functions/cidrsubnet-->
cidrsubnet(prefix, newbits, netnum)

newbits is the number of additional bits with which to extend the prefix.

netnum is a whole number that can be represented 
as a binary integer with no more than newbits binary digits, 
which will be used to populate the additional bits added to the prefix.

> cidrsubnet("172.16.0.0/12", 4, 2)
172.18.0.0/16
> cidrsubnet("10.1.2.0/24", 4, 15)
10.1.2.240/28

## subnetting function
[for i in range(1,6,2) : cidrsubnet("10.123.0.0/16", 8, i)]

1. range(min, max-1, increment) => range(1,6,2) => 1 , 3 , 5
2. for loops the max range, and increments on the 3rd octat, + 8 newbits
3. OUTPUTS: [
  "10.123.1.0/24",
  "10.123.3.0/24",
  "10.123.5.0/24",
]

## TF Data Sources - aws_availability_zones
<!--https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones-->
  we can refrence this value in our aws_subnet resource without hardcoding all available zones
  availability_zone = data.aws_availability_zones.available.names[count.index]

## Spread out subnet deployment into AZs with random_shuffle
<!--https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/shuffle-->
resource "random_shuffle" "az" {
  input        = ["us-west-1a", "us-west-1c", "us-west-1d", "us-west-1e"]
  result_count = 2
}

### for_each would also work here
1. In the root main.tf we could have an locals map, mapping the number of 
   public and private subnets we need 


### We could use a for loop and produce a list that's more round robin rather than random
we use a for loop to loop over the number of times we want to repeat this list value (5),
and we only want the values from the result, hence we use values function to get the 
duple and flatten it into an array.

flatten(values({for i in range(5): i => var.az_list}))

[Example](/0-resources/playground/duplicating_an_array_x_times.tf)

## *important default route and default route table
In network/main.tf
we are directing all traffic in the public route table towards the internet gateway for internet
with: resource "aws_route" "default_route" 

The following resource block specifies that the private route table is using the default
route table created when the vpc is created, thus referencing aws_vpc.my_vpc.default_route_table_id

resource "aws_default_route_table" "tf_private_rt" {
  default_route_table_id = aws_vpc.tf_vpc.default_route_table_id
}

## aws_route_table
<!--https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table-->
1. main associated rt is private so nothing is accidently exposed
2. The subnets in the vpc will be implicitly associated with this rt

## Lifecycle policy and IGW
if the vpc cidr changes and the whole stack needs to be recreated
Problem:
Internet Gateway isn't recreated, it's reassociated (updated in place) to the new vpc
which isn't created yet

Solution:
Lifecycle policy should be added on the VPC, and the "create_before_destroy" set to true 

## Security Groups
<!--https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group-->
dynamic "ingress" {
  for_each = each.value.ingress
  content {
    from_port = ingress.value.from
  }
}
this dynamnic block is nested within the tf_sg for_each block, so it has access to
security_groups variable, the "each keyword" is looping "public"/"private" objects
each.value.ingress => security_groups.public.ingress
ingress.value.from => ingress.[dynamic value].from => ingress.ssh.from

## Creating a subnet group(of 3) for rds to use 
  db_subnet_group = true
  count = var.db_subnet_group ? 1 : 0
Using conditionals tells the sn group to provision or not

*accessing the output will be tricky
output "tf_rds_subnet_group_name_out" {
  value = aws_db_subnet_group.tf_rds_subnet_group[0].name
}

## Generating Provider Schema
To take a look at the password field to see if its hidden and look at other fields
Install jq, and pipe the provider json schema and output as a file command:
sudo apt-get install jq
tf provider schema -json | jq '.' > provider-schema.json

## Adding a load balancer (ALB)
<!--https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb-->
1. provisioned a alb resource
2. took the public security group ids
    aws_security_group.tf_sg["public"].id
    we took the public security group id by using the "public" index value and got the id
3. took all the subnet ids from the networking module
   aws_subnet.tf_public_subnet.*.id
4. using all the output values we can populate "public_sg" and public_subnets so the
   "load-balancing" module can make use of it

## Preventing uuid random name to re-run and force replace old
uuid() and substring to get an short unique id for alb target group
<!--https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group-->
  name     = "tf-lb-tg-${substr(uuid(), 0, 5)}"
Problem:
uuid() reruns every apply so it might break running connections

Solution:

lifecycle {
  ignore_changes = [name]
}

## Preventing update loop issue with changing port values
Problem:
tf_port                = 80
listener_port          = 80
changing these ports will result a force update with the lb_listener
if the target group/listener port is different and the resources are updating
The listener is stuck in update loop
  
Solution:
a new target group is created before the old one is destroyed and thus the listener
can have an arn to work with
  lifecycle {
    ignore_changes = [name]
    create_before_destroy = true
  }

## Adding a load balancer listener
<!--https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener-->
### Using the arn value of other resources
load_balancer_arn = aws_lb.<your lb name>..arn
target_group_arn = aws_lb_target_group.<your tg name>.arn

### Default action
We are using the default action of forward, others include 
authenticate-cognito, redirect and more
<!--https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html-->

## Choosing AMIs from tf data-sources
<!--https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami-->
1. got an ami-id from ec2 console
2. ami-074251216af698218 is a ubuntu AMI
3. ref compute/main.tf for rest

## Creating an ssh key for ec2 instances
1. ssh-keygen -t rsa -f /home/ubuntu//.ssh/<your key name>
2. Create an tf resource to access the public key file
3. To access this file, do <file(/home/ubuntu/.ssh/<your key name>.pub)>

## forcing the ec2 node name to change every apply with keepers att
<!--https://registry.terraform.io/providers/hashicorp/random/latest/docs#resource-keepers-->
by triggering the random_id resource to trigger everytime we need it

## Installing Rancher K3
<!--https://rancher.com/docs/k3s/latest/en/installation/ha/-->
importing user data with a template file and tempalte funciton:
root/user-data.tpl:

 #!/bin/bash
 
 <!-- hostname has to match the aws_instance tag name-->
 sudo hostnamectl set-hostname ${nodename} &&
 curl -sfL https://get.k3s.io | sh -s - server \

 --datastore-endpoint="mysql://${dbuser}:${dbpass}@tcp(${db_endpoint})/${dbname}" \
 --write-kubeconfig-mode 644 \
 --tls-san=$(curl http://169.254.169.254/latest/meta-data/public-ipv4) \
 --token="th1s1sat0k3n!"
 
### Template file & function
<!--https://www.terraform.io/language/functions/templatefile-->
to access the root path => user-data.tpl template
  user_data_path = "${path.root/user-data.tpl}"
  
## SSh into the K3 cluster and checking for the running k3 node
ssh -i ~/.ssh/<your private key name> ubuntu@<ec2 public ip>
kubectl get nodes

## Deploying NGINX to kube and exposing it
<!--create the yaml file while ssh into the ec2 node-->
nano deployment.yaml 
[paste the content from this file](../0-resources/deployment.yaml)
kubectl apply -f deployment.yaml

if we do a:
kubectl get pods

we get one pending and one running pod because one of them has no where to go
we only have one running ec2 instance
change instance_count to 2

now 2 pods are running

### Exposing NGINX within public_sg
adding:
nginx = {
    from        = 8000
    to          = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
will make sure port 8000 is exposed to the intenet

## Adding instances to the target group arn
<!--output from load-balance module-->
output lb_target_group_arn_out, value = aws_lb_target_group.tf_tg.arn
<!--import the value into the compute module-->
lb_target_group_arn = module.load-balance.lb_target_group_arn_out

## Accessing Sensistive outputs
Even if output with the sensitive tag set to true, you might not be able to access
some values, such as user-data from the aws_instance resource.
output "instances" {
    value = {for i in module.compute.instances : i.tags.Name => i.public_ip}
        sensitive = true
}

OUTPUT: 
{
  <OUTPUT NAME>: {
    "type": [
      "object",
      {
        "tf_k3_ec2_node-33895": "string",
        "tf_k3_ec2_node-45008": "string"
      }
    ],
    "value": {
      "tf_k3_ec2_node-33895": "16.170.224.159",
      "tf_k3_ec2_node-45008": "13.53.53.248"
    }
  }
}

Solution:
tf output -json | jq '."<OUTPUT NAME>"."value"'
will give us:
{
  "tf_k3_ec2_node-33895": "16.170.224.159",
  "tf_k3_ec2_node-45008": "13.53.53.248"
}

## Installing kubectl, gain access to rancher node ec2
<!--https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/-->
With local exec provisioner
command = templatefile("${path.root}/scp_script.tpl", {
  nodeip   = self.public_ip
  <!--location of the config yaml file copied fromt he remote instance-->
  k3s_path = "${path.root}/../"  
  nodename = self.tags.Name
})
export KUBECONFIG=../k3s-tf_k3_ec2_node-33895.yaml

## Secure Copy with remote exec provisioners
no more sleep 60 command in our local-exec scp_script.tpl file, 
it arbitrarly delays the copy command to wait for the ec2 to generate the file

We use the remote-exec to ssh into the k3 node instance and check with the delay.sh script

in the delay.sh file
we are waiting for the k3s.yaml file to exist before ending the loop
while [ ! -f /etc/rancher/k3s/k3s.yaml ]; do
    echo -e "Waiting for k3s to bootstrap..."
    sleep 3
done

once the remote is done, the local-exec runs and copies the k3s.yaml config file
into our cloud9 instance


