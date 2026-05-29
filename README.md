

[![Build](https://github.com/anyvm-org/openindiana-builder/actions/workflows/build.yml/badge.svg)](https://github.com/anyvm-org/openindiana-builder/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/anyvm-org/openindiana-builder?include_prereleases&sort=semver)](https://github.com/anyvm-org/openindiana-builder/releases)

Latest: v2.0.8


The image builder for `openindiana`


All the supported releases are here:



| Release | x86_64  |  Comments |
|---------|---------|-----------|
| 202604  |  ✅    | fresh     |
| 202604-build  |  ✅    | build-essential|
| 202510  |  ✅    | fresh     |
| 202510-build  |  ✅    | build-essential|






How to build:

1. Use the [manual.yml](.github/workflows/manual.yml) to build manually.
   
    Run the workflow manually, you will get a view-only webconsole from the output of the workflow, just open the link in your web browser.
   
    You will also get an interactive VNC connection port from the output, you can connect to the vm by any vnc client.

2. Run the builder locally on your Ubuntu machine.

    Just clone the repo. and run:
    ```bash
    bash build.sh conf/openindiana-202604.conf
    ```
   
