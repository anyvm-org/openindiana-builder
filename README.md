

[![Build](https://github.com/anyvm-org/openindiana-builder/actions/workflows/build.yml/badge.svg)](https://github.com/anyvm-org/openindiana-builder/actions/workflows/build.yml)

Latest: v2.1.2


The image builder for `openindiana`


All the supported releases are here:



| Release | Comments | x86_64 |
|---------|---------|---------|
| 202604-build | build-essential | ✅ (rsync,scp,sshfs,nfs,tar) |
| 202604 | fresh | ✅ (rsync,scp,sshfs,nfs,tar) |
| 202510-build | build-essential | ✅ (rsync,scp,sshfs,nfs,tar) |
| 202510 | fresh | ✅ (rsync,scp,sshfs,nfs,tar) |

<!-- extra-column: Comments -->
<!-- extra-value: 202604 fresh -->
<!-- extra-value: 202604-build build-essential -->
<!-- extra-value: 202510 fresh -->
<!-- extra-value: 202510-build build-essential -->

How the images are built:

Each image is built automatically in the
[anyvm-org/openindiana-builder](https://github.com/anyvm-org/openindiana-builder)
repo's GitHub Actions from OpenIndiana's official Hipster media --
either the official cloud image or the official text installer ISO,
depending on the release. The builder boots the media in QEMU, installs
or customizes the system unattended, enables ssh, pre-installs the
packages listed in the conf, and exports the disk as a compressed qcow2
image.

Upstream media: the official OpenIndiana Hipster ISOs and cloud images
from https://dlc.openindiana.org/isos/hipster/ (download page:
https://www.openindiana.org/downloads/).




How to build:

1. Use the [manual.yml](.github/workflows/manual.yml) to build manually.
   
    Run the workflow manually, you will get a view-only webconsole from the output of the workflow, just open the link in your web browser.
   
    You will also get an interactive VNC connection port from the output, you can connect to the vm by any vnc client.

2. Run the builder locally on your Ubuntu machine.

    Just clone the repo. and run:
    ```bash
    python3 build.py conf/openindiana-202604.conf
    ```
   
