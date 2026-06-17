# NAT Gateway as its own stack: a single $0.045/hr + data resource. Bring it up
# only while private workloads (EKS nodes) need outbound internet; destroy it to
# stop the cost without tearing down the VPC.
data "terraform_remote_state" "vpc" {
  backend = "local"
  config  = { path = "../vpc/terraform.tfstate" }
}

locals {
  name                    = data.terraform_remote_state.vpc.outputs.name
  public_subnet           = data.terraform_remote_state.vpc.outputs.public_subnets[0]
  private_route_table_ids = data.terraform_remote_state.vpc.outputs.private_route_table_ids
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${local.name}-nat" }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = local.public_subnet
  tags          = { Name = "${local.name}-nat" }
}

# Default route from each private subnet -> NAT. Removed when this stack is destroyed.
resource "aws_route" "private_nat" {
  count                  = length(local.private_route_table_ids)
  route_table_id         = local.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}
