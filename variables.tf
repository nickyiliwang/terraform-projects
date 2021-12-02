
variable "int_port" {
  type = number
  default = 1880
  
  validation {
    condition = var.int_port == 1880
    error_message = "The internal port must be 1880." 
  }
}

variable "ext_port" {
  type = number
  default = 1880
  
  validation {
    condition = var.ext_port <= 65535 && var.ext_port > 0
    error_message = "Must provide valid external port range 0 - 65535."
  }
}

variable "resource_count" {
  type = number
  default = 2
}
