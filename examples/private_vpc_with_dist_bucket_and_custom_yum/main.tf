/***********************************
      Create Service Account
***********************************/
module "create_service_account" {
  source  = "../../modules/service_account"
  project = var.project
  prefix  = var.prefix
  sa_name = var.sa_name
  providers = {
    google = google.main
  }
}

/***********************************
      VPC configuration
***********************************/
module "setup_network" {
  source               = "../../modules/setup_network"
  project              = var.project
  nics_number          = var.nics_number
  prefix               = var.prefix
  region               = var.region
  subnets-cidr-range   = var.subnets_cidr_range
  set_peering          = var.set_peering
  zone                 = var.zone
  create_vpc_connector = var.create_vpc_connector
  vpc_connector_range  = var.vpc_connector_range
  private_network      = var.private_network

  providers = {
    google = google.deployment
  }
  depends_on = [ module.create_service_account]
}

/***********************************
      Centos local repo
***********************************/
module "create_local_centos_repo" {
  source             = "../../modules/local_centos_repo"
  project            = var.project
  zone               = var.zone
  region             = var.region
  image_name         = var.repo_image_name
  project_image      = var.repo_project_image
  vpcs_peering       = module.setup_network.output-vpcs-names
  public_cidr_range  = var.repo_public_cidr_range
  private_cidr_range = var.repo_private_cidr_range
  vpc_range          = var.vpc_range

  providers = {
    google = google.main
  }

  depends_on = [module.setup_network]
}

/***********************************
     Deploy weka cluster
***********************************/
module "deploy_weka" {
  source                   = "../../modules/deploy_weka"
  cluster_name             = var.cluster_name
  project                  = var.project
  nics_number              = var.nics_number
  vpcs                     = module.setup_network.output-vpcs-names
  prefix                   = var.prefix
  region                   = var.region
  subnets_name             = module.setup_network.output-subnetwork-name
  zone                     = var.zone
  cluster_size             = var.cluster_size
  install_url              = var.install_url
  machine_type             = var.machine_type
  nvmes_number             = var.nvmes_number
  username                 = var.username
  weka_version             = var.weka_version
  bucket-location          = var.bucket_location
  weka_image_name          = var.weka_image_name
  weka_image_project       = var.weka_image_project
  weka_username            = var.weka_username
  vpc_connector            = module.setup_network.output-vpc-connector-name
  sa_email                 = module.create_service_account.outputs-service-account-email
  yum_repo_server          = var.yum_repo_server
  create_cloudscheduler_sa = var.create_cloudscheduler_sa
  private_network          = var.private_network
  providers = {
    google = google.deployment
  }

  depends_on = [module.create_service_account, module.create_local_centos_repo]
}