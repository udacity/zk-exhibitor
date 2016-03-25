EXHIBITOR_VERSION = 3.4.8_1.5.6
# http://cloud-images.ubuntu.com/trusty/current/hwe-v/ : us-west-2,64,hvm-ssd @ 20160325
# ubuntu/images-testing/hvm-ssd/ubuntu-trusty-daily-amd64-server-hwe-v-20160323
SOURCE_AMI := ami-1951b979

WORK_DIR = $(shell pwd)
export

.PHONY: all build

all: build

build:
	@if [ -z "${AWS_ACCESS_KEY_ID}" ] ; then echo "AWS_ACCESS_KEY_ID  must be defined."; false; fi
	@if [ -z "${AWS_SECRET_KEY}" ] ; then echo "AWS_SECRET_KEY must be defined."; false; fi
	@if [ -z "${ATLAS_TOKEN}" ] ; then echo "ATLAS_TOKEN must be defined"; false; fi
	packer build image.json
