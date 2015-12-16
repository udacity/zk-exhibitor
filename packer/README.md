# mesos-host
packer project to define zk exhibitor host image

### Requirements
* packer 0.8.6

### Build Instructions
```bash
# Environment:
#   AWS_ACCESS_KEY_ID - required (make param OR environment variable)
#   AWS_SECRET_KEY    - required (make param OR environment variable)
#   ATLAS_TOKEN       - required (make param OR environment variable)
make build AWS_ACCESS_KEY_ID=XX..XX AWS_SECRET_KEY=YY...YY
```
