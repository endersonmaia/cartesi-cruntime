# (c) Cartesi and individual authors (see AUTHORS)
# SPDX-License-Identifier: Apache-2.0 (see LICENSE)

# syntax=docker.io/docker/dockerfile:1
ARG UBUNTU_BASE_IMAGE=ubuntu:24.04

###############################################################################
# STAGE: base-image
#
# This stage creates a base-image with apt repository cache and ca-certificates
# to be used by later stages.
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

# Get chisel binary
ARG CHISEL_VERSION=1.4.0
WORKDIR /tmp
ADD --checksum=sha256:e2af238e29fccaddb63a57ca2a0ec87fa39c43efb878077f7bfbe2822eb1ea58 \
    "https://github.com/canonical/chisel/releases/download/v${CHISEL_VERSION}/chisel_v${CHISEL_VERSION}_linux_${TARGETARCH}.tar.gz" \
    /tmp/chisel.tar.gz
RUN tar -xvf /tmp/chisel.tar.gz -C /usr/bin/ \
    && rm -f /tmp/chisel.tar.gz

# Extract crun dependencies into the chiselled filesystem
# FIXME: remove this when busybox-static dependecies slices are upstream
ADD https://github.com/endersonmaia/chisel-releases.git#24.04/add-busybox-static-slice /ubuntu-24.04
WORKDIR /rootfs
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

ARG MACHINE_GUEST_TOOLS_VERSION=0.17.2
ARG DEBIAN_FRONTEND=noninteractive
WORKDIR /tmp
ADD --checksum=sha256:c077573dbcf0cdc146adf14b480bfe454ca63aa4d3e8408c5487f550a5b77a41 \
    https://github.com/cartesi/machine-guest-tools/releases/download/v${MACHINE_GUEST_TOOLS_VERSION}/machine-guest-tools_riscv64.deb \
    .
RUN dpkg -x /tmp/machine-guest-tools_riscv64.deb /rootfs

###############################################################################
# STAGE: final image
#
# This stage creates the final image with the crun binary and the chiselled filesystem.
#
FROM --platform=linux/riscv64 scratch
ARG TARGETARCH
ARG CRUN_VERSION=1.26

COPY --chown=root:root --chmod=644 skel/etc/subgid /etc/subgid
COPY --chown=root:root --chmod=644 skel/etc/subuid /etc/subuid
COPY --chown=root:root --chmod=755 skel/etc/cartesi-init.d/cruntime-init /etc/cartesi-init.d/cruntime-init
COPY --from=chisel /rootfs /
COPY --from=machine-guest-tools /rootfs /
ADD --checksum=sha256:24530549d2c0b66450698b70168163cb9d188cd1838408bb41b21c8875cbceaf \
    --chmod=755 \
    https://github.com/containers/crun/releases/download/${CRUN_VERSION}/crun-${CRUN_VERSION}-linux-${TARGETARCH}-disable-systemd \
    /usr/bin/crun
USER dapp
ENTRYPOINT ["rollup-init"]
CMD ["crun", "run", "--config", "/container/config/config.json", "--bundle", "/container", "app"]
