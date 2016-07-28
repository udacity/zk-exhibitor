EXHIBITOR_VERSION = 3.4.8_1.5.6
# ubuntu/images-testing/hvm-ssd/ubuntu-trusty-daily-amd64-server-hwe-v-20160623
SOURCE_AMI := ami-fbf3349b

WORK_DIR = $(shell pwd)
export

.PHONY: all build

all: build

build:
	@if [ -z "${AWS_ACCESS_KEY_ID}" ] ; then echo "AWS_ACCESS_KEY_ID  must be defined."; false; fi
	@if [ -z "${AWS_SECRET_KEY}" ] ; then echo "AWS_SECRET_KEY must be defined."; false; fi
	@if [ -z "${ATLAS_TOKEN}" ] ; then echo "ATLAS_TOKEN must be defined"; false; fi
	packer build image.json
