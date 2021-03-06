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
  keepers = {
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
  user_data = templatefile(var.user_data_path, {
    // nodename doesn't like underscores as well 
    // underscore makes it invalid as an dns name
    nodename    = "tf-k3-ec2-node-${random_id.tf_ec2_node_id[count.index].dec}"
    db_endpoint = var.db_endpoint
    dbname      = var.db_name
    dbuser      = var.db_user
    dbpassword  = var.db_password
  })


  root_block_device {
    volume_size = var.vol_size
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = self.public_ip
      private_key = file(var.ssh_private_key_path)
    }

    script = "${path.cwd}/delay.sh"
  }
  provisioner "local-exec" {
    command = templatefile("${path.cwd}/scp_script.tpl", {
      private_key = file(var.ssh_private_key_path)
      nodeip      = self.public_ip
      k3s_path    = "${path.cwd}/../"
      nodename    = self.tags.Name

    })
  }
  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.cwd}/../k3s-${self.tags.Name}.yaml"
  }
}

// Placing each ec2 instance (id) into the target group we have in the networking module
resource "aws_lb_target_group_attachment" "tf_tg_attach" {
  count            = var.instance_count
  target_group_arn = var.lb_target_group_arn
  target_id        = aws_instance.tf_ec2_node[count.index].id
  port             = var.tg_attach_port
}