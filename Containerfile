# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# Base image: Universal Blue Kinoite with the open NVIDIA kernel modules.
#
# `kinoite-nvidia:stable` is a stale 2023 tag, so this intentionally tracks
# `latest` (currently Fedora 44). The ublue `nvidia` variant is built with
# `akmods-nvidia-open`; see:
# https://github.com/ublue-os/main/blob/main/Containerfile
FROM ghcr.io/ublue-os/kinoite-nvidia:latest

### [IM]MUTABLE /opt
## Fedora Atomic points /opt at /var/opt. Android Studio must live in an
## immutable, image-managed location, so replace the symlink with a real
## directory before the build script runs.
RUN if [ -L /opt ]; then rm /opt; fi && mkdir -p /opt

### MODIFICATIONS
## Image customizations live in build_files/build.sh.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
