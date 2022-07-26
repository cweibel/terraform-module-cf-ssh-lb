variable subnet_ids            {}  # The AWS Subnet Id to place the lb into
variable resource_tags         {}  # AWS tags to apply to resources
variable vpc_id                {}  # The VPC Id
variable ssh_domain            {}  # url used for cf ssh commands
variable route53_zone_id       {}  # Route53 zone id
variable internal_lb           { default = true } # Determine whether the load balancer is internal-only facing

variable enable_route_53       { default = 1 }  # Disable if using CloudFlare or other DNS


################################################################################
# CF SSH NLB 
################################################################################
resource "aws_lb" "cf_ssh_nlb" {
  name               = "cf-ssh-nlb"
  internal           = var.internal_lb
  load_balancer_type = "network"
  subnets            = var.subnet_ids
  # NOTE: NLB "network" LB does not support security groups.
  tags               = merge(
      {Name              = "cf-ssh-nlb"}, 
      {Environment       = "cf-ssh" },
      var.resource_tags
  )
}

################################################################################
# NLB Target Group
################################################################################
resource "aws_lb_target_group" "cf_ssh_nlb_tg" {
  name         = "cf-ssh-nlb-tg"
  port         = 2222
  protocol     = "TCP"
  vpc_id       = var.vpc_id
  target_type  = "instance"
  tags         = merge(
      {Name              = "cf-ssh-nlb-tg"}, 
      {Environment       = "cf-ssh" },
      var.resource_tags
  )
}



###############################################################################
# NLB Listener for CF SSH
###############################################################################
resource "aws_lb_listener" "cf_ssh_nlb_listener_sys" {
  load_balancer_arn = aws_lb.cf_ssh_nlb.arn
  port = "2222"
  protocol = "TCP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.cf_ssh_nlb_tg.arn
  }

  tags               = merge(
      {Name              = "cf-ssh-nlb-listener-sys"}, 
      {Environment       = "cf-ssh" },
      var.resource_tags
  )  
}

################################################################################
# CF SSH NLB Route53 DNS CNAME Record - SSH Domain
################################################################################
resource "aws_route53_record" "cf_ssh_nlb_record_ssh" {
  count   = var.enable_route_53
  zone_id = var.route53_zone_id
  name = var.ssh_domain
  type = "CNAME"
  ttl = "60"
  records = ["${aws_lb.cf_ssh_nlb.dns_name}"]
}

output "dns_name" {value = aws_lb.cf_ssh_nlb.dns_name}
output "lb_name"  {value = aws_lb.cf_ssh_nlb.name }
output "lb_target_group_name" { value = aws_lb_target_group.cf_ssh_nlb_tg.name }
