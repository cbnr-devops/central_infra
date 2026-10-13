location = "australiaeast"

pipeline_service_principal_object_id = "5cfea5dd-d6cd-4ad7-9928-6a6004feb215"

# Temporary allowlist retained for the private endpoint cutover. Set this to []
# only after the Managed DevOps Pool smoke pipeline verifies private ACR access.
agent_vm_ips = [
  "20.190.96.216/32",
  "20.5.169.239/32",
  "106.222.203.33/32",
]
