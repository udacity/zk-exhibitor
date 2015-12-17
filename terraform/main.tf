/*** VARIABLES ***/
variable "subnets" {
  description = "comma separated list of VPC subnet IDs for the cluster"
}
variable "vpc_id" {
  description = "VPC associated with the provided subnets"
}
variable "admin_security_group" {
  description = "existing security group that should be granted administrative access to ZooKeeper (e.g., 'sg-123456')"
}
variable "dd_api_key" {
  description = "datadog api key"
}
variable "exhibitor_s3_bucket" {
  description = "bucket for Exhibitor backups of ZK configs"
}
variable "cluster_name" {
  description = "name of cluster, key prefix for S3 backups. Should be unique per S3 bucket"
}
variable "exhibitor_s3_region" {
  description = "region for exhibitor backups of ZK configs"
  default = "us-west-1"
}
variable "host_artifact" {
  description = "atlas artifact name for exhibitor"
  default = "udacity/zk-exhibitor-ubuntu-14.04-amd64"
}
variable "host_version" {
  description = "version metadata for atlas artifact (e.g. udacity/zk-exhibitor-ubuntu-14.04-amd64)"
  default = "3.4.6_1.5.6"
}
variable "zk_exhibitor_docker_image" {
  description = "ZK+Exhibitor Docker image (format: [<registry>[:<port>]/]<repository>:<version>)"
  default = "udacity/zk-exhibitor:3.4.6_1.5.6"
}
variable "instance_type" {
  description = "ec2 instance type"
  default = "m4.large"
}
variable "key_name" {
  description = "existing ec2 KeyPair to be associated with all cluster instances for ssh access"
}
variable "cluster_size" {
  description = "number of nodes"
  default = 5
}
variable "root_volume_size" {
  description = "size of root volume"
  default = 20
}

/*** RESOURCES ***/
resource "atlas_artifact" "zk-exhibitor-host" {
  name = "${var.host_artifact}"
  type = "aws.ami"
  metadata {
    version = "${var.host_version}"
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "client" {
  name = "${var.cluster_name}-zkex-client-sg"
  description = "Security group for zookeeper clients, grants access to the associated zookeeper cluster"
  vpc_id = "${var.vpc_id}"
  tags {
    Name = "${var.cluster_name}-zkex-client-sg}"
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "load_balancer" {
  name = "${var.cluster_name}-zkex-lb-sg"
  description = "open access between zk servers, restricted access to lb and client sgs"
  vpc_id = "${var.vpc_id}"
  tags {
    Name = "${var.cluster_name}-zkex-lb-sg"
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port   = 80
    protocol = "tcp"
    security_groups = ["${aws_security_group.client.id}"]
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "server" {
  name = "${var.cluster_name}-zkex-server-sg"
  description = "open access between zk servers, restricted access to lb and client sgs"
  vpc_id = "${var.vpc_id}"
  tags {
    Name = "${var.cluster_name}-zkex-server-sg"
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    self = true
  }
  ingress {
    from_port = 2121
    to_port   = 2121
    protocol = "tcp"
    security_groups = ["${aws_security_group.client.id}"]
  }
  ingress {
    from_port = 8181
    to_port   = 8181
    protocol = "tcp"
    security_groups = ["${aws_security_group.load_balancer.id}"]
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_elb" "lb" {
  name = "${var.cluster_name}-lb"
  subnets = ["${split(",", var.subnets)}"]
  security_groups = ["${aws_security_group.load_balancer.id}", "${var.admin_security_group}"]
  cross_zone_load_balancing = true
  internal = true

  listener {
    lb_port = 80
    instance_port = 8181
    instance_protocol = "http"
    lb_protocol = "http"
  }

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 5
    interval            = 30
    timeout             = 5
    target              = "HTTP:8181/exhibitor/v1/cluster/state"
  }

  tags {
    monitoring = "datadog"
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_iam_role_policy" "access_s3" {
    name = "${var.cluster_name}-iam-access-s3"
    role = "${aws_iam_role.server.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect"   : "Allow",
    "Action"   : "s3:*",
    "Resource" : ["arn:aws:s3:::${var.exhibitor_s3_bucket}","arn:aws:s3:::${var.exhibitor_s3_bucket}/*"]
  }]
}
EOF
}

resource "aws_iam_role" "server" {
    name = "${var.cluster_name}-iam-role"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  lifecycle { create_before_destroy = true }
}

resource "aws_iam_instance_profile" "server" {
  name = "${var.cluster_name}-iam-instance-profile"
  roles = ["${aws_iam_role.server.name}"]

  lifecycle { create_before_destroy = true }
}

resource "aws_launch_configuration" "servers" {
  name_prefix       = "${var.cluster_name}-zkex-"
  instance_type     = "${var.instance_type}"
  image_id          = "${atlas_artifact.zk-exhibitor-host.metadata_full.ami_id}"
  key_name          = "${var.key_name}"
  iam_instance_profile = "${aws_iam_instance_profile.server.id}"
  security_groups   = ["${var.admin_security_group}", "${aws_security_group.server.id}"]

  user_data = <<EOF
#!/usr/bin/env bash
set -euxo pipefail

# docker
rm /etc/init/docker.override
service docker start

# datadog
sed -i -e 's/__DD_API_KEY/${var.dd_api_key}/g;s/__DD_TAGS/${var.cluster_name}/g' /etc/dd-agent/datadog.conf
update-rc.d datadog-agent defaults
service datadog-agent start

# zk-exhibitor
docker create --name=zk-exhibitor \
    -e S3_BUCKET=${var.exhibitor_s3_bucket} \
    -e S3_PREFIX=${var.cluster_name} \
    -e AWS_REGION=${var.exhibitor_s3_region} \
    -e HOSTNAME=$(ec2metadata --local-ipv4) \
    --net=host \
    --restart=always \
    --log-driver syslog \
    --log-opt syslog-facility=daemon \
    --log-opt tag=zk-exhibitor \
    ${var.zk_exhibitor_docker_image}
rm /etc/init/zk-exhibitor.override
service zk-exhibitor start
EOF

  root_block_device {
    volume_size           = "${var.root_volume_size}"
    volume_type           = "gp2"
    delete_on_termination = true
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "servers" {
  name = "${var.cluster_name}-asg"
  launch_configuration = "${aws_launch_configuration.servers.name}"
  max_size = 9
  min_size = 1
  desired_capacity = "${var.cluster_size}"
  force_delete = false
  load_balancers = ["${aws_elb.lb.name}"]
  vpc_zone_identifier = ["${split(",", var.subnets)}"]

  tag {
    key = "monitoring"
    value = "datadog"
    propagate_at_launch = true
  }
  tag {
    key = "role"
    value = "zookeeper"
    propagate_at_launch = true
  }

  lifecycle { create_before_destroy = true }
}

/*** OUTPUTS ***/
output "exhibitor_discovery_url" {
  value = "http://${aws_elb.lb.dns_name}/exhibitor/v1/cluster/list"
}

output "client_security_group" {
  value = "${aws_security_group.client.id}"
}
