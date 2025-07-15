##############################################################################################################
#
# FortiGate Standalone Load Balanced Deployment
# Terraform deployment template for Microsoft Azure
#
# Management Access:
# - FortiGate A: https://${fgt_a_mgmt_ip}/
# - FortiGate B: https://${fgt_b_mgmt_ip}/
#
# Internal Load Balancers:
# - External ILB: ${external_ilb_ip} (port1 traffic)
# - Internal ILB: ${internal_ilb_ip} (port2 traffic)
#
# Deployment location: ${location}
# Admin username: ${username}
#
##############################################################################################################

FortiGate A Configuration:
- Public Management IP: ${fgt_a_mgmt_ip}
- External Interface (port1): ${fgt_a_private_ip_address_ext}
- Internal Interface (port2): ${fgt_a_private_ip_address_int}

FortiGate B Configuration:
- Public Management IP: ${fgt_b_mgmt_ip}
- External Interface (port1): ${fgt_b_private_ip_address_ext}
- Internal Interface (port2): ${fgt_b_private_ip_address_int}

Load Balancer Configuration:
- External ILB Private IP: ${external_ilb_ip}
- Internal ILB Private IP: ${internal_ilb_ip}

##############################################################################################################
# BEWARE: State files contain sensitive data.
#         After deployment, secure the Terraform state and output files.
##############################################################################################################