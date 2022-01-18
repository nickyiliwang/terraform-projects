# root/main.tf

module "networking" {
  source   = "./networking"
  vpc_cidr = local.vpc_cidr
  public_sn_count = 2
  private_sn_count = 3
  // even nums for public, max 255 to have enough subnets
  public_cidrs = [for i in range(2, 255, 2): cidrsubnet(local.vpc_cidr, 8, i)]
  private_cidrs = [for i in range(2, 255, 2): cidrsubnet(local.vpc_cidr, 8, i)]
}
