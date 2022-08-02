project                  = "wekaio-rnd"
region                   = "europe-west1"
zone                     = "europe-west1-b"
prefix                   = "weka"
subnets_cidr_range       = ["10.0.0.0/24", "10.1.0.0/24", "10.2.0.0/24", "10.3.0.0/24"]
nics_number              = 4
cluster_size             = 7
machine_type             = "c2-standard-8"
nvmes_number             = 2
weka_version             = "4.0.0.70-gcp"
bucket_location          = "EU"
vpc_connector_range      = "10.8.0.0/28"
create_vpc_connector     = true
sa_name                  = "deploy-sa"
cluster_name             = "poc"
sg_public_ssh_cidr_range = ["0.0.0.0/0"]
create_cloudscheduler_sa = true
private_network          = false
weka_image_name          = "centos-7-v20220719"
weka_image_project       = "centos-cloud"
set_peering              = true