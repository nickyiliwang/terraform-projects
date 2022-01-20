# database/variables.tf

variable "db_storage" {}
variable "db_instance_class" {}
variable "db_engine_version" {}
variable "db_name" {}
variable "db_user" {}
variable "db_password" {}
variable "db_subnet_group_name" {}
variable "vpc_security_group_ids" {}
variable "db_identifier" {}
variable "skip_db_final_snapshot" {}