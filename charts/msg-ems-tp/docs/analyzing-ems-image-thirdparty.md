# Analyzing container images and their associated licenses

This document describes how to analyze container images for software artifacts and associated licenses.

## Base container image

This project uses a [Ubuntu](https://hub.docker.com/_/ubuntu) [official container](https://hub.docker.com/_/ubuntu) LTS image as the common base image layer for building images.

See the [license information](https://ubuntu.com/legal/open-source-licences?release=jammy) for details on Ubuntu licenses and software package types.

As with all container images, the Debian container image can contain other software (such as `bash`, `glibc`, `zlib`, and others from the base distribution, along with any direct or indirect dependencies of the primary software included in the built image) that might be subjected to other licenses.

The following links provide auto-detected license information for the Ubuntu official images:

- [ubuntu](https://github.com/docker-library/repo-info/tree/master/repos/ubuntu)
    - [local](https://github.com/docker-library/repo-info/blob/master/repos/ubuntu/local)
    - [remote](https://github.com/docker-library/repo-info/blob/master/repos/ubuntu/remote)

For example, you can find information about the artifacts of the [ubuntu:22.04](https://github.com/docker-library/repo-info/blob/master/repos/ubuntu/local/22.04.md) official image.

**Note**: The image user has the responsibility to ensure that any use of the image complies with all relevant licenses for all software contained within.

## Additional software packages

Building images often installs additional software packages (fetched from the official distribution software repositories, from other user added repositories, or from specific locations), in addition to the packages already provided by the base image.
Each such specified package can, in turn, install other software packages as dependencies.

**Note**: There are different ways to extract the list of installed packages and other installed artifacts.
Providing detailed instructions on software license analysis specialized tools is outside the scope of this document.
Retrieving information on software artifacts other than software packages installed with the package manager tools is also outside the scope of this document.
The following sections provide basic examples using standard container and package management tools.

### Manually retrieve installed packages information

You can use the command `dpkg-query` to retrieve the full list of installed packages in a container image.

**Example**: To retrieve the list of installed packages in the `ubuntu:22.04` image:
```bash
$ docker run --rm ubuntu:22.04 dpkg-query -l
```
**Result**:
```
> docker run --rm ubuntu:22.04 dpkg-query -l
Unable to find image 'ubuntu:22.04' locally
22.04: Pulling from library/ubuntu
aece8493d397: Already exists
Digest: sha256:2b7412e6465c3c7fc5bb21d3e6f1917c167358449fecac8176c6e496e5c1f05f
Status: Downloaded newer image for ubuntu:22.04
Desired=Unknown/Install/Remove/Purge/Hold
| Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend
|/ Err?=(none)/Reinst-required (Status,Err: uppercase=bad)
||/ Name                    Version                                 Architecture Description
+++-=======================-=======================================-============-========================================================================
ii  adduser                 3.118ubuntu5                            all          add and remove users and groups
ii  apt                     2.4.10                                  amd64        commandline package manager
ii  base-files              12ubuntu4.4                             amd64        Debian base system miscellaneous files
ii  base-passwd             3.5.52build1                            amd64        Debian base system master password and group files
ii  bash                    5.1-6ubuntu1                            amd64        GNU Bourne Again SHell
ii  bsdutils                1:2.37.2-4ubuntu3                       amd64        basic utilities from 4.4BSD-Lite
ii  coreutils               8.32-4.1ubuntu1                         amd64        GNU core utilities
ii  dash                    0.5.11+git20210903+057cd650a4ed-3build1 amd64        POSIX-compliant shell
ii  debconf                 1.5.79ubuntu1                           all          Debian configuration management system
ii  debianutils             5.5-1ubuntu2                            amd64        Miscellaneous utilities specific to Debian
ii  diffutils               1:3.8-0ubuntu2                          amd64        File comparison utilities
ii  dpkg                    1.21.1ubuntu2.2                         amd64        Debian package management system
ii  e2fsprogs               1.46.5-2ubuntu1.1                       amd64        ext2/ext3/ext4 file system utilities
ii  findutils               4.8.0-1ubuntu3                          amd64        utilities for finding files--find, xargs
ii  gcc-12-base:amd64       12.3.0-1ubuntu1~22.04                   amd64        GCC, the GNU Compiler Collection (base package)
...
```

### Manually retrieve installed packages licenses

You can use the command `dpkg` to retrieve the license for any installed package.

**Example**: To retrieve the license information for the installed package `apt`:
```bash
docker run --rm ubuntu:22.04  bash -c 'cat `dpkg -L apt | grep copyright`'
```
**Result**:
```
Apt is copyright 1997, 1998, 1999 Jason Gunthorpe and others.
Apt is currently developed by APT Development Team <deity@lists.debian.org>.

License: GPLv2+

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.

See /usr/share/common-licenses/GPL-2, or
<http://www.gnu.org/copyleft/gpl.txt> for the terms of the latest version
of the GNU General Public License.
```

### Manually retrieve installed packages sources

You can use the command `apt-get` to retrieve the source for any installed package.

**Example**: To retrieve the source for the installed package `apt`:
```bash
docker run --rm ubuntu:22.04 bash -c 'dpkg-query --print-avail apt'
```
**Result**:
```
Package: apt
Priority: important
Section: admin
Installed-Size: 4156
Origin: Ubuntu
Maintainer: Ubuntu Developers <ubuntu-devel-discuss@lists.ubuntu.com>
Bugs: https://bugs.launchpad.net/ubuntu/+filebug
Architecture: amd64
Version: 2.4.5
...
SHA256: 89b093ec665072b3400881120aa3f4460222caa6a5d6c6ccb3d016beb18e7a00
SHA512: 5d4e2b80ed0262dcfa9cbc3ca45e663e8e3e080691603eb464c035ad3785c595ca8915b2436ee43242b6cc904c2fd0c0a81ddd902cc2e04fb56f5afa9c1fc2b0
Task: minimal, server-minimal
Description-md5: 9fb97a88cb7383934ef963352b53b4a7
Build-Essential: yes
```

### Manually retrieve installed files

You can use the command `docker` to extract the contents of a container for further inspection.
Here we show 2 common methods to extract the image contents without running the container.

#### Method 1: Using a temporal container image to extract the files

Create a temporal container image based on the image you want to inspect, and export its whole filesystem (or parts of it).

**Example**:

1. Create a temporal container image called `temp-container`, based on the `unknown-image:latest` image:
    ```bash
    docker create --name temp-container unknown-image:latest
    ```

2. Extract the whole container image filesystem as a TAR file:
   ```bash
    docker export temp-container > temp-container.tar
    ```

    Or, if you want to list only the included files:
    ```bash
    docker export temp-container | tar t > temp-container-files.txt
    ```

This method is a direct way to extract the image's final filesystem. 
It provides a **composite view of a container instance's filesystem**.

**Note**: This is the fastest way to list the included files or extract individual files.

#### Method 2: Extract the container image layers as a set of layers

Create a TAR file with all the individual image layers that compose the final container image.

**Example**:

- Use the command `docker image save` to create a TAR file containing all the container image layers:
    ```bash
    docker image save unknown-image:latest > temp-image.tar
    ```

The TAR file includes a `manifest.json` file, which describes the image's layers and a set of separate directories containing the content of each of the individual layers.

This method produces an archive that exposes the container image format, not the container instances created from it.
It provides a **layered view of the container image**.

**Note**: This is useful when you want to evaluate each layer's role in building the image.

#### Layered view vs composite view

The following diagram illustrates the differences between the layered view and the composite view of a container image. 

![](container-image-views.png)

References:
- For more information on the docker command arguments, see the [Docker CLI](https://docs.docker.com/engine/reference/commandline/docker/) documentation.
- For more information on the container image format, see the [OCI image format specification](https://github.com/opencontainers/image-spec/blob/main/spec.md).
