project     = "projectx"
region      = "ap-south-1"
require_mfa = true

# --- User provisioning (optional) ---
# Flip to true and list usernames to have Terraform create the IAM users and
# place them in the correct group. Leave false to only create groups/roles and
# add existing users via the console.
create_users = false

dev_users  = [] # e.g. ["dev.bunty", "dev.bandhu"]
qa_users   = [] # e.g. ["qa.hira"]
prod_users = [] # e.g. ["ops.hiresh"]
