#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

FEDORA_VERSION="$(rpm -E %fedora)"
BUILD_TMP="$(mktemp -d /var/tmp/amp-build.XXXXXX)"
trap 'rm -rf "${BUILD_TMP}"' EXIT

### Repositories
#
# Terra: main repo plus extras. The terra-nvidia, terra-mesa, and
# terra-multimedia subrepos are intentionally NOT enabled:
#   - ublue already ships the open NVIDIA driver and a full Mesa build
#   - RPM Fusion is the multimedia source for this image
# Enabling those subrepos would fight the ublue NVIDIA stack.
dnf5 install -y --nogpgcheck \
    --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
    terra-release terra-gpg-keys
dnf5 install -y terra-release-extras

# RPM Fusion: the ublue NVIDIA image disables these while installing the
# driver. Re-enable them and make sure the release packages are present.
for repo in free nonfree; do
    if ! rpm -q "rpmfusion-${repo}-release" >/dev/null 2>&1; then
        dnf5 install -y \
            "https://mirrors.rpmfusion.org/${repo}/fedora/rpmfusion-${repo}-release-${FEDORA_VERSION}.noarch.rpm"
    fi
done
dnf5 config-manager setopt "rpmfusion*".enabled=1

# Fedora's OpenH264 repo is disabled by the ublue NVIDIA setup. It is needed
# for the GStreamer/Firefox H.264 plugins below.
dnf5 config-manager setopt fedora-cisco-openh264.enabled=1

### Multimedia codecs
#
# ublue already ships a full ffmpeg build from negativo17. Keep that full
# build and add the RPM Fusion GStreamer plugins/codecs that are not part of
# the base image. We deliberately do not install libavcodec-freeworld: it is
# only a complement to ffmpeg-free, and this image uses full ffmpeg.
if rpm -q ffmpeg-free >/dev/null 2>&1; then
    dnf5 swap -y ffmpeg-free ffmpeg --allowerasing
fi

dnf5 install -y --allowerasing --setopt=install_weak_deps=False \
    ffmpeg \
    gstreamer1-plugins-good \
    gstreamer1-plugins-good-extras \
    gstreamer1-plugins-bad-free \
    gstreamer1-plugins-bad-free-extras \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-ugly \
    gstreamer1-libav \
    gstreamer1-plugin-openh264 \
    mozilla-openh264

### Android tooling
#
# Android Studio is installed from Google's official Linux archive because
# Terra's stable package trails upstream. The bundled JBR is used, so no
# system JDK is required for the IDE itself.
dnf5 install -y android-tools libxcrypt-compat

ANDROID_STUDIO_VERSION="2026.2.1.8"
ANDROID_STUDIO_SHA256="f8775c67cf899d9133712a2d7ee3ef7231e07fb16dbe0544c47e5f5babd5931b"
ANDROID_STUDIO_URL="https://edgedl.me.gvt1.com/android/studio/ide-zips/${ANDROID_STUDIO_VERSION}/android-studio-rabbit1-linux.tar.gz"

curl -fL --retry 3 --retry-delay 5 \
    -o "${BUILD_TMP}/android-studio.tar.gz" \
    "${ANDROID_STUDIO_URL}"
echo "${ANDROID_STUDIO_SHA256}  ${BUILD_TMP}/android-studio.tar.gz" | sha256sum -c -
tar -xzf "${BUILD_TMP}/android-studio.tar.gz" -C /opt
ln -sfn /opt/android-studio/bin/studio.sh /usr/local/bin/android-studio
rm -f "${BUILD_TMP}/android-studio.tar.gz"

### OpenCode 2 (stable channel, pinned)
OPENCODE_VERSION="2.2.0"
mkdir -p /root
HOME=/root curl -fsSL https://opencode.ai/v2/install | \
    HOME=/root bash -s -- --version "${OPENCODE_VERSION}" --no-modify-path
install -Dm0755 /root/.opencode/bin/opencode /usr/local/bin/opencode
rm -rf /root/.opencode

### T3 Code CLI (stable channel, pinned)
#
# The official installer puts the versioned runtime under T3CODE_HOME and a
# `t3` launcher on PATH. The desktop UI is served by `t3`; use the desktop
# entry in system_files to launch it from KDE.
T3CODE_VERSION="0.1.3"
curl -fsSL -o "${BUILD_TMP}/t3-install.sh" https://t3.codes/install.sh
env HOME=/root \
    T3CODE_CHANNEL=stable \
    T3CODE_VERSION="${T3CODE_VERSION}" \
    T3CODE_HOME=/usr/share/t3code \
    T3CODE_INSTALL_BIN_DIR=/usr/local/bin \
    sh "${BUILD_TMP}/t3-install.sh"

### System units
systemctl enable podman.socket

### Assertions
# Fail the build immediately if a requested component did not land.
rpm -q nvidia-driver kmod-nvidia libva-nvidia-driver
rpm -q ffmpeg gstreamer1-plugins-ugly gstreamer1-libav
test -x /opt/android-studio/bin/studio.sh
test -x /usr/local/bin/opencode
test -x /usr/local/bin/t3
opencode --version
t3 --help >/dev/null

### Cleanup
dnf5 clean all
rm -rf /var/cache/dnf /var/cache/libdnf5 /root/.cache
rm -f /var/log/dnf5.log* /var/log/dnf.log*
