# resource "ibm_resource_group" "resource_group" {
#     name = var.resource_group_name
# }

data "ibm_resource_group" "existing_resource_group" {
  name = var.resource_group_name
}

# resource "ibm_is_vpc" "vpc" {
#     name = "${var.resource_prefix}-vpc-${var.resource_suffix}"
#     resource_group = data.ibm_resource_group.existing_resource_group.name
#     address_prefix_management = "manual"
#     classic_access = false
#     default_network_acl_name = "${var.resource_prefix}-vpc-${var.resource_suffix}-default-acl"
#     default_security_group_name = "${var.resource_prefix}-vpc-${var.resource_suffix}-default-sg"
#     default_routing_table_name = "${var.resource_prefix}-vpc-${var.resource_suffix}-default-rt"
#     tags = var.tags
# }

data "ibm_is_vpc" "existing_vpc" {
  identifier = var.vpc_id
}

resource "ibm_is_vpc_address_prefix" "address_prefix_zone_1" {
    name = "${var.resource_prefix}-address-prefix-${var.resource_suffix}-z1"
    zone = "${var.region}-1"
    vpc  = data.ibm_is_vpc.existing_vpc.id
    cidr = "10.50.0.0/16"
}

# resource "ibm_is_subnet" "subnet_zone1_internal" {
#     depends_on = [
#       ibm_is_vpc_address_prefix.address_prefix_zone_1
#     ]
#     name            = "${var.resource_prefix}-subnet-${var.resource_suffix}-z1-internal"
#     vpc             = data.ibm_is_vpc.existing_vpc.id
#     zone            = "${var.region}-1"
#     ipv4_cidr_block = "10.40.10.0/24"
#     routing_table   = data.ibm_is_vpc.existing_vpc.default_routing_table
# }

# resource "ibm_is_vpc_routing_table" "rt_zone1_external" {
#   vpc   = data.ibm_is_vpc.existing_vpc.id
#   name  = "${var.resource_prefix}-vpc-${var.resource_suffix}-external-rt"
# }

resource "ibm_is_subnet" "squid_external_subnet" {
    depends_on = [
      ibm_is_vpc_address_prefix.address_prefix_zone_1
    ]
    name            = "${var.resource_prefix}-subnet-${var.resource_suffix}-z1-external"
    vpc             = data.ibm_is_vpc.existing_vpc.id
    zone            = "${var.region}-1"
    ipv4_cidr_block = "10.50.10.0/24"
    routing_table   = data.ibm_is_vpc.existing_vpc.default_routing_table
}


resource "ibm_is_public_gateway" "public_gateway" {
  name = "${var.resource_prefix}-public-gw-${var.resource_suffix}"
  resource_group = data.ibm_resource_group.existing_resource_group.id
  vpc  = data.ibm_is_vpc.existing_vpc.id
  zone = "${var.region}-1"
}

resource "ibm_is_subnet_public_gateway_attachment" "public_gateway_squid_external_subnet_attachment" {
  subnet                = ibm_is_subnet.squid_external_subnet.id
  public_gateway         = ibm_is_public_gateway.public_gateway.id
}


resource "ibm_is_ssh_key" "sshkey" {
  name            = "${var.resource_prefix}-key"
  resource_group  = data.ibm_resource_group.existing_resource_group.id
  public_key = var.ssh_public_key
  type       = "rsa"
}


data "ibm_is_image" "ubuntu" {
  name = var.ubuntu_image
}

resource "ibm_is_subnet_reserved_ip" "squid_reserved_ip" {
    subnet      = ibm_is_subnet.squid_external_subnet.id
    address     = "10.50.10.5"
    name        = "squid-reserved-ip"
}

resource "ibm_is_virtual_network_interface" "squid_vni"{
    name                            = "squid-vni"
    resource_group                  = data.ibm_resource_group.existing_resource_group.id
    allow_ip_spoofing               = true
    enable_infrastructure_nat       = true
    primary_ip {
        auto_delete       = false
        reserved_ip       = ibm_is_subnet_reserved_ip.squid_reserved_ip.reserved_ip
    }
    subnet   = ibm_is_subnet.squid_external_subnet.id
}


resource "ibm_is_security_group" "squid_sg" {
  name           = "squid-sg"
  vpc            = data.ibm_is_vpc.existing_vpc.id
  resource_group = data.ibm_resource_group.existing_resource_group.id
}

resource "ibm_is_security_group_rule" "squid_inbound_roks" {
  group     = ibm_is_security_group.squid_sg.id
  direction = "inbound"
  remote    = "10.10.0.0/24" # ROKS cluster subnets
  tcp {
    port_min = 3128
    port_max = 3128
  }
}

resource "ibm_is_instance" "squid" {
  name                      = "squid"
  resource_group            = data.ibm_resource_group.existing_resource_group.id
  vpc                       = data.ibm_is_vpc.existing_vpc.id
  zone                      = "${var.region}-1"
  image                     = data.ibm_is_image.ubuntu.id
  profile                   = "bx2-2x8"
  keys                      = [ibm_is_ssh_key.sshkey.id]

  metadata_service {
    enabled = false
    protocol = "http"
    response_hop_limit = 1
  }

  primary_network_attachment {
    name = "squid-primary-att"
    virtual_network_interface {
      id = ibm_is_virtual_network_interface.squid_vni.id
    }
  }

  user_data = templatefile("${path.module}/files/squid-setup.sh.tftpl", {
    allowlist = var.allowlist,
    addressprefixes = [ibm_is_vpc_address_prefix.address_prefix_zone_1.cidr]
  })

}

# resource "ibm_is_vpc_routing_table_route" "default-gw" {
#   vpc           = data.ibm_is_vpc.existing_vpc.id
#   routing_table = data.ibm_is_vpc.existing_vpc.default_routing_table
#   zone          = "${var.region}-1"
#   name          = "${var.region}-1-default-gw"
#   destination   = "0.0.0.0/0"
#   action        = "deliver"
#   next_hop      = ibm_is_subnet_reserved_ip.squid_reserved_ip.address
#   priority      = 4
# }

# resource "ibm_is_vpc_routing_table" "custom_rt" {
#   vpc  = data.ibm_is_vpc.existing_vpc.id
#   name = "${var.resource_prefix}-custom-rt"
# }

# resource "ibm_is_vpc_routing_table_route" "custom_default_route" {
#   vpc           = data.ibm_is_vpc.existing_vpc.id
#   # routing_table = ibm_is_vpc_routing_table.custom_rt.id
#   routing_table = "r010-9fa28615-fc2c-46f1-80ae-30df814ea1a1" # fix needed
#   zone          = "${var.region}-1"
#   name          = "custom-default-route"
#   destination   = "0.0.0.0/0"
#   action        = "deliver"
#   next_hop      = ibm_is_subnet_reserved_ip.squid_reserved_ip.address
#   priority      = 1
# }

# resource "ibm_is_subnet_routing_table_attachment" "associate_custom_rt" {
#   depends_on = [ibm_is_vpc_routing_table.custom_rt]
#   subnet        = ibm_is_subnet.subnet_zone1_internal.id
#   # routing_table = ibm_is_vpc_routing_table.custom_rt.id
#   routing_table = "r010-9fa28615-fc2c-46f1-80ae-30df814ea1a1" # fix needed
# }

# resource "ibm_is_vpn_server_route" "vpn_server_roks_api_route" {
#   vpn_server  = ibm_is_vpn_server.vpn_server.id
#   destination = "166.8.0.0/13" # Adjust CIDR to include the ROKS API server
#   action      = "deliver"
#   name        = "roks-api-route"
# }

resource "ibm_is_security_group_rule" "vpn_server_outbound" {
  group     = tolist(ibm_is_vpn_server.vpn_server.security_groups)[0]
  direction = "outbound"
  remote    = "166.8.0.0/13" # Adjust as needed
  tcp {
    port_min = 443
    port_max = 443
  }
}

resource "ibm_is_vpc_routing_table_route" "to-ibm-cse" {
  vpc           = data.ibm_is_vpc.existing_vpc.id
  routing_table = data.ibm_is_vpc.existing_vpc.default_routing_table
  zone          = "${var.region}-1"
  name          = "${var.region}-1-to-ibm-cse"
  destination   = "161.26.0.0/16"
  action        = "delegate"
  next_hop      = "0.0.0.0"
  priority      = 2
}

resource "ibm_is_vpc_routing_table_route" "to-vpc" {
  vpc           = data.ibm_is_vpc.existing_vpc.id
  routing_table = data.ibm_is_vpc.existing_vpc.default_routing_table
  zone          = "${var.region}-1"
  name          = "${var.region}-1-to-vpc"
  destination   = "10.0.0.0/8"
  action        = "delegate_vpc"
  next_hop      = "0.0.0.0"
  priority      = 2
}

# resource "ibm_is_vpc_routing_table_route" "to_squid_proxy" {
#   vpc              = data.ibm_is_vpc.existing_vpc.id
#   routing_table    = "r010-9ec0e62b-b0f3-4bef-93ca-3345b897d94a"
#   zone             = "${var.region}-1"
#   destination      = "10.30.20.5/32"
#   next_hop         = "10.0.0.1"  # Ensure the correct next hop
#   action           = "deliver"
# }

data "ibm_resource_instance" "existing_secret_manager" {
  name = var.secret_manager_instance
}

resource "ibm_iam_authorization_policy" "vpn_sm" {
  source_service_name      = "is"
  source_resource_type     = "vpn-server"
  source_resource_group_id = data.ibm_resource_group.existing_resource_group.id
  target_service_name      = "secrets-manager"
  # target_resource_group_id = data.ibm_resource_group.existing_resource_group.id
  target_resource_group_id = "2063e0e13e16462698b56dbe156ed48f"
  roles                    = ["SecretsReader"]
}


resource "ibm_sm_secret_group" "c2svpn_secret_group" {
  name        = "c2svpn-${var.region}"
  region      = var.region
  instance_id = data.ibm_resource_instance.existing_secret_manager.guid
}

resource "ibm_sm_private_certificate_configuration_root_ca" "private_certificate_root_CA" {
  instance_id                       = data.ibm_resource_instance.existing_secret_manager.guid
  region                            = var.region
  name                              = "${var.resource_prefix}-root-ca-${var.region}"
  common_name                       = "${var.resource_prefix} ${var.region} Root CA"
  permitted_dns_domains             = ["${var.resource_prefix}.ca"]
  organization                      = ["${var.resource_prefix} Org"]
  ou                                = ["${var.resource_prefix} OU"]
  country                           = ["CA"]
  issuing_certificates_urls_encoded = true
  max_ttl                           = "87600h"
  # max_path_length                   = 10
}

resource "ibm_sm_private_certificate_configuration_intermediate_ca" "intermediate_CA" {
  instance_id    = data.ibm_resource_instance.existing_secret_manager.guid
  name           = "${var.resource_prefix}-intermediate-ca-${var.region}"
  region         = var.region
  common_name    = "${var.resource_prefix} ${var.region} Intermidiate CA"
  signing_method = "internal"
  issuer         = ibm_sm_private_certificate_configuration_root_ca.private_certificate_root_CA.name
  max_ttl        = "17520h"
}

resource "ibm_sm_private_certificate_configuration_template" "certificate_template" {
  instance_id                 = data.ibm_resource_instance.existing_secret_manager.guid
  region                      = var.region
  name                        = "${var.resource_prefix}-${var.region}-template-ca"
  certificate_authority       = ibm_sm_private_certificate_configuration_intermediate_ca.intermediate_CA.name
  allow_any_name              = true
  allow_wildcard_certificates = true
  allow_bare_domains          = true
  allowed_domains_template    = true
  max_ttl                     = "8760h"
}

resource "ibm_sm_private_certificate" "vpn_server" {
  name                 = "c2svpn-vpn-server-${var.region}"
  instance_id          = data.ibm_resource_instance.existing_secret_manager.guid
  region               = var.region
  certificate_template = ibm_sm_private_certificate_configuration_template.certificate_template.name
  common_name          = "c2svpn.${var.region}.${var.resource_prefix}.ca"
  labels               = ["vpn-server"]
  rotation {
    auto_rotate = true
    interval    = 182
    unit        = "day"
  }
  secret_group_id = ibm_sm_secret_group.c2svpn_secret_group.secret_group_id
  ttl             = "8760h"
}

resource "ibm_sm_private_certificate" "vpn_client" {
  name                 = "c2svpn-vpn-client-${var.region}"
  instance_id          = data.ibm_resource_instance.existing_secret_manager.guid
  region               = var.region
  certificate_template = ibm_sm_private_certificate_configuration_template.certificate_template.name
  common_name          = "c2svpn-client.${var.region}.${var.resource_prefix}.ca"
  labels               = ["vpn-client"]
  secret_group_id = ibm_sm_secret_group.c2svpn_secret_group.secret_group_id
  ttl             = "8760h"
}

resource "ibm_is_vpn_server" "vpn_server" {
  depends_on = [
    ibm_sm_private_certificate.vpn_server,
    ibm_sm_private_certificate.vpn_client
  ]
  name                   = "${var.resource_prefix}-c2svpn-${var.region}"
  resource_group         = data.ibm_resource_group.existing_resource_group.id
  client_ip_pool         = "10.66.0.0/22"
  client_dns_server_ips  = ["8.8.8.8"]
  client_idle_timeout    = 2800
  certificate_crn        = ibm_sm_private_certificate.vpn_server.crn
  enable_split_tunneling = true
  protocol               = "udp"
  port                   = 443
  subnets                = [ibm_is_subnet.squid_external_subnet.id]
  security_groups        = [data.ibm_is_vpc.existing_vpc.default_security_group]

  client_authentication {
    method        = "certificate"
    client_ca_crn = ibm_sm_private_certificate.vpn_client.crn
  }
}

resource "ibm_is_vpn_server_route" "vpn_server_route" {
  vpn_server    = ibm_is_vpn_server.vpn_server.vpn_server
  destination   = ibm_is_vpc_address_prefix.address_prefix_zone_1.cidr
  action        = "translate"
  name          = "vpc-zone-1-route"
}


resource "ibm_is_security_group_rule" "allow_incomming_for_vpn" {
  group     = data.ibm_is_vpc.existing_vpc.default_security_group
  direction = "inbound"
  remote    = "0.0.0.0/0"
  udp {
    port_min = 443
    port_max = 443
  }
}


# output "vpn_server_certificate_crn" {
#   value = ibm_sm_private_certificate.vpn_server.crn
# }

# output "vpn_routing_table"{
#   value = ibm_is_vpc_routing_table.custom_rt.id
# }

# output "subnet" {
#  value =  ibm_is_subnet.subnet_zone1_internal.id
# }
  # routing_table = ibm_is_vpc_routing_table.custom_rt.id

# output "resource_group_name" {
#   value = var.resource_group_name
# }