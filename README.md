# amp

My personal [Universal Blue](https://universal-blue.org/) image: a Kinoite desktop with the open NVIDIA kernel modules and a small developer-tooling layer.

The repository follows the [ublue-os/image-template](https://github.com/ublue-os/image-template) layout, so image changes are made in `build_files/build.sh` and `system_files/`, built and published by GitHub Actions, and installed with `bootc`.

## Base image

```text
ghcr.io/ublue-os/kinoite-nvidia:latest
```

`kinoite-nvidia` is Universal Blue's Kinoite build with the **open NVIDIA kernel modules** (`akmods-nvidia-open`), including the NVIDIA container toolkit and `libva-nvidia-driver`.

> `kinoite-nvidia:stable` is a stale 2023 tag. This image tracks `latest`, which is the current stable Fedora release (Fedora 44 at the time of writing).

## What is included

- Kinoite / KDE Plasma desktop from Universal Blue.
- Open NVIDIA kernel modules, `nvidia-container-toolkit`, `supergfxctl`, and VA-API bridging.
- **Terra** package repository (main and extras). The Terra `nvidia`, `mesa`, and `multimedia` subrepos are intentionally not enabled because they would conflict with the ublue NVIDIA stack and RPM Fusion.
- **RPM Fusion** free and nonfree repositories, enabled.
- Full multimedia stack: UBlue's negativo17 full `ffmpeg`, GStreamer bad/libav codecs, plus the Fedora `ugly-free` set, OpenH264 for GStreamer and Firefox, with `fedora-cisco-openh264` enabled. RPM Fusion's `-freeworld` GStreamer packages are intentionally not layered over the UBlue stack because they conflict on the x265 soname.
- **Android Studio** `2026.2.1.8` (Rabbit 1) from Google's official Linux archive, plus `android-tools` (adb/fastboot) and desktop integration.
- **OpenCode** 2.x stable, pinned to `2.2.0`, installed as `opencode`.
- **T3 Code** stable CLI, pinned to `0.1.3`, installed as `t3` with a KDE launcher that opens its local web UI.
- `podman.socket` enabled.

Android Studio is installed under `/opt/android-studio`, which is why the `Containerfile` converts `/opt` from the Fedora Atomic `/var/opt` symlink into a real directory.

## Builds

GitHub Actions is the only supported build environment for this repository.

- Pull requests run the container build as a validation step and do **not** publish.
- Pushes to `main` build, push, and (when signing is configured) sign the image.
- A daily scheduled build keeps the image current with the base image and repositories.

The image is published as:

```text
ghcr.io/mheci/amp:latest
```

### Local builds (optional)

The template's `Justfile` and `Containerfile` also work with `podman`:

```bash
just build
just ostree-rechunk
```

They are useful for debugging, but CI is the source of truth.

## Install / switch

On a bootc system:

```bash
sudo bootc switch ghcr.io/mheci/amp:latest
sudo systemctl reboot
```

Inspect the current deployment with `sudo bootc status`.

## Image signing

The image should be signed before it is treated as trusted. Signing is skipped automatically while no key is configured, so the build does not fail on a fresh repository.

Generate a passwordless cosign key pair:

```bash
COSIGN_PASSWORD="" cosign generate-key-pair
```

Add the **private** key as the `SIGNING_SECRET` repository secret:

```bash
gh secret set SIGNING_SECRET < cosign.key
```

Commit the public key and never commit `cosign.key`:

```bash
git add cosign.pub
git commit -m "Add image signing public key"
git push
```

Once `SIGNING_SECRET` exists, the workflow signs the pushed digest with cosign. Verify with:

```bash
cosign verify --key cosign.pub ghcr.io/mheci/amp:latest
```

## Updating pinned tools

The developer tools are pinned in `build_files/build.sh` for reproducible image builds:

| Tool | Variable | Current |
| --- | --- | --- |
| Android Studio | `ANDROID_STUDIO_VERSION` / `ANDROID_STUDIO_SHA256` | `2026.2.1.8` |
| OpenCode | `OPENCODE_VERSION` | `2.2.0` |
| T3 Code | `T3CODE_VERSION` | `0.1.3` |

When bumping Android Studio, update the version, download URL, and SHA-256 checksum together. The checksum is published on the [Android Studio download page](https://developer.android.com/studio).

OpenCode and T3 Code are installed from their official stable release trains with explicit versions, so an image rebuild cannot silently jump to a nightly build.

## Disk images

The manual **Build disk images** workflow can produce a QCOW2 or Anaconda ISO from the published image. The ISO kickstart switches the installed system to `ghcr.io/mheci/amp:latest`.

- QCOW2/raw uses `disk_config/disk.toml`.
- Anaconda ISO uses `disk_config/iso.toml`.

Disk builds are manual because they are slow and should run only after the container image has been published.

## Repository layout

| Path | Purpose |
| --- | --- |
| `Containerfile` | Base image and build entrypoint |
| `build_files/build.sh` | Package/tool installation and image assertions |
| `system_files/` | Files copied into the image (desktop entries, etc.) |
| `disk_config/` | bootc-image-builder configurations |
| `.github/workflows/build.yml` | OCI image build/push/sign workflow |
| `.github/workflows/build-disk.yml` | Manual disk image workflow |
| `image-template.env` | Image name, organization, and metadata |

## Notes

- This is a personal image. It is published publicly for my own machines, not as a supported distribution.
- Secure Boot works through the Universal Blue akmods keys already present in the base image; no additional MOK enrollment is needed for the NVIDIA modules.
- RPM Fusion and Terra are third-party repositories. Their packages are used at your own risk.
