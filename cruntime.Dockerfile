# (c) Cartesi and individual authors (see AUTHORS)
# SPDX-License-Identifier: Apache-2.0 (see LICENSE)

# syntax=docker.io/docker/dockerfile:1
ARG UBUNTU_BASE_IMAGE=ubuntu:24.04

###############################################################################
# STAGE: base-image
#
# This stage creates a base-image with apt repository cache and ca-certificates
# to be used by later stages.
FROM ${UBUNTU_BASE_IMAGE} AS base-image
FROM --platform=linux/riscv64 ${UBUNTU_BASE_IMAGE} AS base-image
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl

###############################################################################
# STAGE: chisel
#
# Build the chiselled filesystem based on the desired slices.
# This image should have the machine-emulator-tools and crun dependencies
# installed.
#
#FIXME: replace the image with the official one when it's available
#       from: docker.io/risv64/ubuntu to: docker.io/library/ubuntu
FROM base-image AS chisel
ARG TARGETARCH

WORKDIR /rootfs

# Get chisel binary
ARG CHISEL_VERSION=1.2.0
ADD "https://github.com/canonical/chisel/releases/download/v${CHISEL_VERSION}/chisel_v${CHISEL_VERSION}_linux_${TARGETARCH}.tar.gz" chisel.tar.gz
RUN tar -xvf chisel.tar.gz -C /usr/bin/

# Extract crun dependencies into the chiselled filesystem
# FIXME: remove this when busybox-static dependecies slices are upstream
ADD https://github.com/endersonmaia/chisel-releases.git#24.04/add-busybox-static-slice /ubuntu-24.04
RUN chisel cut \
    --release /ubuntu-24.04 \
    --root /rootfs \
    --arch=${TARGETARCH} \
    base-files_base \
    base-files_release-info \
    base-passwd_data \
    busybox-static_bins \
    libc6_libs \
    # crun dependencies
    libcap2_libs \
    libgcc-s1_libs \
    libseccomp2_libs \
    libstdc++6_libs \
    libyajl2_libs \
    uidmap_bins

# Prepare the chiselled filesystem with the necessary configuration
# some directories, dapp user and root's shell
RUN <<EOF
set -e
ln -s /bin/busybox bin/sh
mkdir -p proc sys dev mnt container/rootfs container/config
echo "dapp:x:1000:1000::/home/dapp:/bin/sh" >> etc/passwd
echo "dapp:x:1000:" >> etc/group
mkdir home/dapp
chown 1000:1000 home/dapp
sed -i '/^root/s/bash/sh/g' etc/passwd
EOF

###############################################################################
# STAGE: machine-guest-tools
#
# Install the machine-guest-tools package into the chiselled filesystem.
#
FROM base-image AS machine-guest-tools

ARG MACHINE_GUEST_TOOLS_VERSION=0.17.1
ARG DEBIAN_FRONTEND=noninteractive
RUN <<EOF
set -e

cd /tmp
curl -fsSL -O https://github.com/cartesi/machine-guest-tools/releases/download/v${MACHINE_GUEST_TOOLS_VERSION}/machine-guest-tools_riscv64.deb
echo "96625d97354c1cc905a8630f3d715f64b14bc5b89f3e30913d2eb02da3a01f20a7784d32c2ed340ca401dce4d1bc0e6bebfc3fbb3808725225c5793b16fa6ef4 /tmp/machine-guest-tools_riscv64.deb" \
  | sha512sum -c
dpkg -x /tmp/machine-guest-tools_riscv64.deb  /rootfs
rm /tmp/machine-guest-tools_riscv64.deb
EOF

###############################################################################
# STAGE: final image
#
# This stage creates the final image with the crun binary and the chiselled filesystem.
#
FROM --platform=linux/riscv64 scratch
ARG TARGETARCH
ARG CRUN_VERSION=1.22

COPY --chown=root:root --chmod=644 skel/etc/subgid /etc/subgid
COPY --chown=root:root --chmod=644 skel/etc/subuid /etc/subuid
COPY --chown=root:root --chmod=755 skel/etc/cartesi-init.d/cruntime-init /etc/cartesi-init.d/cruntime-init
COPY --from=chisel /rootfs /
COPY --from=machine-guest-tools /rootfs /
ADD --checksum=sha256:b13640ec30fee7e333ca62f11bd435e1913dba0641d728b366818286a37da80c \
    --chmod=755 \
    https://github.com/containers/crun/releases/download/${CRUN_VERSION}/crun-${CRUN_VERSION}-linux-${TARGETARCH}-disable-systemd \
    /usr/bin/crun

ENTRYPOINT ["rollup-init", "crun", "run", "--config", "/container/config/config.json", "--bundle", "/container", "app"]
