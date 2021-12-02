
output "local-ip-plus-external-ports" {
  # we are using a for loop + the join function to keep the code DRY
  value       = [for i in docker_container.nodered_container[*]: join(":", [i.ip_address, i.ports[0].external])] 
  description = "Local ip:external-port"
}

output "container-names" {
# we are using the splat ([*]) syntax here to make our output DRY
  value       = docker_container.nodered_container[*].name
  description = "The name of the container"
}