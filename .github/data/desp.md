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
