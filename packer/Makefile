EXHIBITOR_VERSION = 3.4.6_1.5.6
# http://cloud-images.ubuntu.com/trusty/current/hwe-v/ : us-west-2,64,hvm-ssd @ 20151215
SOURCE_AMI := ami-984a55f9

WORK_DIR = $(shell pwd)
export

.PHONY: all build

all: build

build:
	@if [ -z "${AWS_ACCESS_KEY_ID}" ] ; then echo "AWS_ACCESS_KEY_ID  must be defined."; false; fi
	@if [ -z "${AWS_SECRET_KEY}" ] ; then echo "AWS_SECRET_KEY must be defined."; false; fi
	@if [ -z "${ATLAS_TOKEN}" ] ; then echo "ATLAS_TOKEN must be defined"; false; fi
	packer build image.json
