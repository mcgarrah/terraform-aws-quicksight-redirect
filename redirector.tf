module "cf-url-redirectory" {
  source                        = "./modules/cf-url-redirector"
  #version                      = "0.0.0"
  hosted_zone                   = "mcgarrah.org"
  quicksight_admin_user_name    = "mcgarrah@mcgarrah.org"
  vpc_id                        = var.vpc_id
  vpc_subnet_ids                = var.vpc_subnet_ids
}
