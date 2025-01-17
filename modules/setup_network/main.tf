locals {
  vpc_length = length(var.vpcs) == 0 ? var.vpcs_number : length(var.vpcs)
  temp = flatten([
  for from in range(local.vpc_length) : [
  for to in range(local.vpc_length) : {
    from = from
    to   = to
  }
  ]
  ])
  peering-list = [for t in local.temp : t if t["from"] != t["to"]]
}

# ====================== vpc ==============================
resource "google_project_service" "project-compute" {
  project = var.project
  service = "compute.googleapis.com"
  disable_on_destroy = false
  disable_dependent_services = false
  depends_on = [google_project_service.project-gcp-api]
}

resource "google_project_service" "project-gcp-api" {
  project = var.project
  service = "iam.googleapis.com"
  disable_on_destroy = false
  disable_dependent_services = false
}

resource "google_project_service" "service-cloud-api" {
  project = var.project
  service = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
  disable_dependent_services = false
}

data "google_compute_network" "vpc_list_ids"{
  count = length(var.vpcs)
  name  = var.vpcs[count.index]
}

data "google_compute_subnetwork" "subnets_list_ids" {
  count  = length(var.subnets)
  name   = var.subnets[count.index]
}


resource "google_compute_network" "vpc_network" {
  count                   = length(var.vpcs) == 0 ? var.vpcs_number :0
  name                    = "${var.prefix}-vpc-${count.index}"
  auto_create_subnetworks = false
  mtu                     = var.mtu

  depends_on = [google_project_service.project-compute, google_project_service.project-gcp-api]
}

# ======================= subnet ==========================
resource "google_compute_subnetwork" "subnetwork" {
  count         = length(var.subnets) == 0 ? var.vpcs_number : 0
  name          = "${var.prefix}-subnet-${count.index}"
  ip_cidr_range = var.subnets-cidr-range[count.index]
  region        = var.region
  network       = length(var.vpcs) == 0 ? google_compute_network.vpc_network[count.index].name : data.google_compute_network.vpc_list_ids[count.index].name
  private_ip_google_access = true

}


resource "google_compute_network_peering" "peering" {
  count        = var.set_peering ? length(local.peering-list) : 0
  name         = "${var.prefix}-peering-${local.peering-list[count.index]["from"]}-${local.peering-list[count.index]["to"]}"
  network      = length(var.vpcs) == 0 ?  google_compute_network.vpc_network[local.peering-list[count.index]["from"]].self_link : data.google_compute_network.vpc_list_ids[local.peering-list[count.index]["from"]].self_link
  peer_network = length(var.vpcs) == 0 ?  google_compute_network.vpc_network[local.peering-list[count.index]["to"]].self_link :  data.google_compute_network.vpc_list_ids[local.peering-list[count.index]["to"]].self_link

  depends_on = [google_compute_subnetwork.subnetwork]
}

# ========================= sg =================================
resource "google_compute_firewall" "sg_public_ssh" {
  count         = var.private_network ? 0 : local.vpc_length
  name          = "${var.prefix}-sg-ssh-${count.index}"
  network       = length(var.vpcs) == 0 ? google_compute_network.vpc_network[count.index].name : data.google_compute_network.vpc_list_ids[count.index].name
  source_ranges = var.sg_public_ssh_cidr_range
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_tags = ["ssh"]
}

resource "google_compute_firewall" "sg_private" {
  count         = length(var.vpcs) == 0 ? length(google_compute_network.vpc_network) : length(var.vpcs)
  name          = "${var.prefix}-sg-all-${count.index}"
  network       = length(var.vpcs) == 0 ? google_compute_network.vpc_network[count.index].name :  data.google_compute_network.vpc_list_ids[count.index].id
  source_ranges = length(var.vpcs) == 0 ? google_compute_subnetwork.subnetwork.*.ip_cidr_range : data.google_compute_subnetwork.subnets_list_ids.*.ip_cidr_range
  allow {
    protocol = "all"
  }
  source_tags = ["all"]
}

#================ Vpc connector ==========================
resource "google_project_service" "project-vpc" {
  project = var.project
  service = "vpcaccess.googleapis.com"
  disable_on_destroy = false
  disable_dependent_services = false
  depends_on = [google_project_service.project-gcp-api]
}

resource "google_vpc_access_connector" "connector" {
  count         = var.vpc_connector_name == "" ? 1 : 0
  name          = "${var.prefix}-connector"
  ip_cidr_range = var.vpc_connector_range
  region = lookup(var.vpc_connector_region_map, var.region, var.region)
  network       = length(var.vpcs) == 0 ? google_compute_network.vpc_network[0].id :  data.google_compute_network.vpc_list_ids[count.index].id

  depends_on = [google_project_service.project-vpc]
}

#============== Health check ============================
resource "google_compute_firewall" "fw_hc" {
  name          = "${var.prefix}-fw-allow-hc"
  direction     = "INGRESS"
  network       = length(var.vpcs) == 0 ? google_compute_network.vpc_network[0].self_link : data.google_compute_network.vpc_list_ids[0].self_link
  allow {
    protocol = "tcp"
  }
  # allow all access from GCP internal health check ranges
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16", "35.235.240.0/20"]
  source_tags = ["allow-health-check"]
}

# allow communication within the subnet
resource "google_compute_firewall" "fw_ilb_to_backends" {
  name          = "${var.prefix}-fw-allow-ilb-to-backends"
  direction     = "INGRESS"
  network       = length(var.vpcs) == 0 ? google_compute_network.vpc_network[0].self_link :  data.google_compute_network.vpc_list_ids[0].self_link
  source_ranges = length(var.vpcs) == 0 ? [var.subnets-cidr-range[0]] : [data.google_compute_subnetwork.subnets_list_ids[0].ip_cidr_range]
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
}

# =================== private DNS ==========================
locals {
  network_list = length(var.vpcs) == 0 ? google_compute_network.vpc_network.*.self_link : data.google_compute_network.vpc_list_ids.*.self_link
}

resource "google_project_service" "project-dns" {
  project = var.project
  service = "dns.googleapis.com"
  disable_on_destroy = false
  disable_dependent_services = false
}

resource "google_dns_managed_zone" "private-zone" {
  name        = "${var.prefix}-private-zone"
  dns_name    = "${var.prefix}.private.net."
  project     = var.project
  description = "private dns weka.private.net"
  visibility  = "private"

  private_visibility_config {
    dynamic "networks" {
      for_each = local.network_list
      content {
        network_url = networks.value
      }
    }
  }
  depends_on = [google_project_service.project-dns]
}
