# compute/main.tf

# ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-20211129
data "aws_ami" "k3_server_ami" {
  // everything is found on the ec2 console
  most_recent = true
  owners      = ["099720109477"]

  filter {
    // always get the ami with the latest date 
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
}

resource "random_id" "tf_ec2_node_id" {
  byte_length = 2
  count       = var.instance_count

  // Generate a new id each time we switch to a new key_name
  // Can do with ami as well 
  keepers {
    key_name = var.key_name
  }

}

// ssh key_name
resource "aws_key_pair" "tf_ec2_auth" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_instance" "tf_ec2_node" {
  count         = var.instance_count
  instance_type = var.instance_type # t3.micro is required for rancher k3 to have the cores
  ami           = data.aws_ami.k3_server_ami.id

  tags = {
    Name = "tf_k3_ec2_node-${random_id.tf_ec2_node_id[count.index].dec}"
  }

  key_name               = aws_key_pair.tf_ec2_auth.id
  vpc_security_group_ids = [var.public_sg]
  subnet_id              = var.public_subnets[count.index]
  # user_data = ""
  root_block_device {
    volume_size = var.vol_size
  }

}
