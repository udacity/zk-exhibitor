Terraform module for an [Exhibitor](https://github.com/Netflix/exhibitor)-managed [ZooKeeper](http://zookeeper.apache.org/) cluster.

## Overview

This module bootstraps a HA ZooKeeper cluster. The ZK nodes are managed by Exhibitor with S3 for backups and automatic node discovery.

ZooKeeper and Exhibitor are run via a Docker container. You may use the default ([udacity/zk-exhibitor](https://hub.docker.com/r/udacity/zk-exhibitor)) or provide your own image.

The servers are part of an auto-scaling group distributed across AZs. Incrementing, decrementing, or otherwise modifying the server list should be handled gracefully by ZooKeeper (thanks to Exhibitor).

The module creates a security group for ZK clients, the id for which is exposed as an output (`client_security_group`).

The module also creates an internal-facing ELB for clients to interact with Exhibitor via a static endpoint. This is especially useful for node discovery, so Exhibitor's `/cluster/list` API is exposed as an output as well (`exhibitor_discovery_url`).

Note that this module must be used with Amazon VPC.

## Usage

### 1. Create an Admin security group
This is a VPC security group containing access rules for cluster administration, and should be locked down to your IP range, a bastion host, or similar. This security group will be associated with the ZooKeeper servers.

Inbound rules are at your discretion, but you may want to include access to:
* `22 [tcp]` - SSH port
* `2181 [tcp]` - ZooKeeper client port
* `8181 [tcp]` - Exhibitor HTTP port (for both web UI and REST API)

### 2. Use the module from a terraform tempalte
See `terraform/main.tf` for the full list of parameters, descriptions, and default values.

```bash
module "zk-ensemble" {
  source = "github.com/udacity/zk-exhibitor//terraform"
  cluster_name           = "test20151215b"
  cluster_size           = 3   /* an odd number between 1 and 9 inclusive */
  exhibitor_s3_region    = "us-west-1"
  exhibitor_s3_bucket    = "zk-kafka"
  admin_security_group   = "sg-aaaaaaa5"
  /* ASG will allocate instances in these subnets.
     Best practice is to have subnets in separate AZs. */
  subnets                = "subnet-xxxxxxxx,subnet-yyyyyyyy,subnet-zzzzzzzz"
  vpc_id                 = "vpc-bbbbbbbb"
  key_name               = "deploy-key"
  dd_api_key             = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}

resource "aws_instance" "client" {
  ...
  security_groups = ["${module.zk-ensemble.client_security_group}"]
}
```
### 3. Outputs
* `exhibitor_discovery_url` : url backed by ELB that emitts a JSON payload enumerating ensemble members
* `client_security_group`   : add this SG to any instances that need access to the zk ensemble

### 4. Watch the cluster converge
Once the ensemble has been provisioned, visit `http://<host>:8181/exhibitor/v1/ui/index.html` on one of the nodes. You will need to do this from a location granted access by the specified `admin_security_group`.

You should see Exhibitor's management UI with a list of ZK nodes in this cluster. Exhibitor adds each node to the cluster via a rolling restart, so you may see nodes getting added and restarting during the first few minutes they're up.
