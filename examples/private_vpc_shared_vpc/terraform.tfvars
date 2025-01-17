project                  = "wekaio-rnd"
region                   = "europe-west1"
zone                     = "europe-west1-b"
host_project             = "test-tf-vars"
subnets_cidr_range       = ["10.0.0.0/24", "10.1.0.0/24", "10.2.0.0/24", "10.3.0.0/24"]
shared_vpcs              = ["global-test-tf-vars-vpc"]
host_shared_range        = ["10.26.1.0/24"]
cluster_size             = 7
install_url              = "gs://weka-installation/weka-4.0.1.37-gcp.tar"
nvmes_number             = 2
yum_repo_server          = "http://yum.weka.private.net"
vpc_connector_range      = "10.8.0.0/28"
cluster_name             = "poc"
private_network          = true
