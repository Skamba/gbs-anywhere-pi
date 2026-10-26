# gbs-anywhere Pi image: design

Date: 2026-10-26. Facts below were checked on this date; versions are named
where they matter.

## Why

gbs-anywhere (https://github.com/Skamba/gbs-anywhere, AGPL-3.0-or-later)
stands in for the espresso machine a Mahlkönig grinder syncs with. Today
people run it with Docker or install its `.deb` by hand. The person this
repository is for is a **technical novice with an E64 WS** who wants
Grind-by-Sync to work: flash a card, power up a Pi, open an app on the phone,
type an address into the grinder, done. They will not use a terminal.

This repository is a public companion to upstream. It holds no app code: it
builds a ready-to-flash image of Raspberry Pi OS Lite (arm64) with one pinned
gbs-anywhere release installed from its release `.deb`, and publishes it.

Success: on a real Pi, Imager's settings apply, the Pi joins Wi-Fi (or
Ethernet), `http://gbs-anywhere.local/` shows the app, `systemctl status
gbs-anywhere` is active, and a novice who mistyped the Wi-Fi password can
still recover with a phone. A video and wiki page for novices come later and
are out of scope.

## Goals

1. A build that produces `gbs-anywhere-<app version>-<build>-arm64.img.xz`:
   Raspberry Pi OS Lite (Trixie, arm64) plus one exact gbs-anywhere version
   from its release `.deb`, verified against that release's `SHA256SUMS`.
2. A Raspberry Pi Imager manifest per release, so Imager's OS customisation
   (hostname, user, Wi-Fi, SSH, locale) works for this image.
3. A setup hotspot for when the Pi can't join the Wi-Fi it was given
   (wrong password, new router).
4. A GitHub Actions workflow on `ubuntu-24.04-arm` (native, no emulation)
   that builds on pull requests (no publishing) and, for a release, creates a
   public **pre-release** that the owner turns into a full release after
   testing by hand.
5. A README for novices: Imager, first boot, the setup hotspot, opening the
   app, setting up the E64 WS, updating, licences.

## Non-goals (this version)

- An apt repository for updates. Updating means re-flashing; a signed apt
  repo on GitHub Pages is a likely later step (see "Later").
- Publishing GPL source bundles or a written offer. The owner chose not to,
  for now; the README carries notices only.
- A static IP set by the image. The Pi stays on DHCP.
- Rebuilding images for Raspberry Pi OS updates alone. A new image follows a
  new gbs-anywhere release (or a manual run); every image is tested by hand.
- Building the app from source, or copying any upstream file into this repo.
- Supporting 32-bit Pis or anything other than Raspberry Pi hardware that
  64-bit Raspberry Pi OS supports (Pi 3, 4, 5, Zero 2 W, and their
  derivatives like the 400/500 and CM3/4/5).

## Anti-goals (would make it a failure even if it works)

- Any default password: no user password, no shared hotspot password.
- SSH on by default. It stays off unless the person turns it on in Imager.
- Calling the image "Raspberry Pi OS", putting "Raspberry Pi" in the repo or
  image name, or any vendor logo (Raspberry Pi, Mahlkönig, Hemro).
- Anyone's local setup in the repo: real IP addresses (documentation
  examples like `192.168.1.20` are fine), hostnames, serials, account names,
  logs from real devices. Upstream AGENTS.md "Public repository wording"
  applies here too.
- Changing Raspberry Pi OS Lite more than needed: only the hostname, the app,
  the setup hotspot and the glue between them.
- Publishing anything (repo, push, tag, release) without asking the owner.
  The one standing exception, agreed with the owner: once the workflow
  exists, a dispatch or manual run creates a public pre-release by itself.

## Decisions

### Build tool: pi-gen, called directly

- Use **pi-gen** (https://github.com/RPi-Distro/pi-gen), the tool Raspberry
  Pi builds its official images with, **pinned to the tag
  `2026-10-06-raspios-trixie-arm64`** (the tag of the current official
  release, on the `arm64` branch). Moving to a newer Raspberry Pi OS is a pull
  request that changes the tag.
- Run its `build-docker.sh` ourselves. Do **not** use `usimd/pi-gen-action`:
  its last release (v1.11.0, 2025-10-12) predates its arm64-runner fixes, which
  sit unreleased on `main`.
- Not rpi-image-gen: its base is not Raspberry Pi OS Lite (no cloud-init, no
  Imager customisation, networkd/iwd instead of NetworkManager), and its docs
  point to pi-gen for modifying the official OS.
- Stages: `stage0 stage1 stage2` unchanged, plus one custom stage of ours
  after `stage2`. Only our stage exports an image (stage2's export is
  skipped).
- pi-gen settings: `RELEASE=trixie`, `TARGET_HOSTNAME=gbs-anywhere`,
  `DEPLOY_COMPRESSION=xz`, `ENABLE_CLOUD_INIT=1` (default), `ENABLE_SSH=0`
  (default), `FIRST_USER_PASS` unset (account locked),
  `DISABLE_FIRST_BOOT_USER_RENAME=0` (default), `WPA_COUNTRY` unset (so
  Wi-Fi stays off until Imager sets a country; see the setup hotspot). Other
  settings stay at pi-gen's defaults.
- Packages come from the live Debian and Raspberry Pi archives at build time,
  so each build has current updates even with pi-gen pinned.
- homebridge's image builds the same way on `ubuntu-24.04-arm` in about 7.5
  minutes (https://github.com/homebridge/homebridge-raspbian-image), which is
  the evidence that this runner works. Free disk on the runner (nominally
  14 GB) and our build time are unmeasured; the first CI run will show them.

### The app

- Version pinned in one file in the repo (e.g. `GBS_ANYWHERE_VERSION`
  containing `0.3.1`); a workflow input or dispatch payload can override it.
- The custom stage downloads `gbs-anywhere_<v>-1_arm64.deb` and `SHA256SUMS`
  from `https://github.com/Skamba/gbs-anywhere/releases/download/v<v>/`,
  checks the `.deb` against `SHA256SUMS` (the build fails on mismatch or a
  missing line), copies it into the image and runs `apt-get install` on it
  inside the chroot, then deletes the copy.
- The `.deb` installs the binary, `/etc/default/gbs-anywhere`, the systemd
  unit (enabled), and its licence files. We change nothing in the package or
  its config, except that the service is **disabled** at boot so that only
  the network glue below starts it.

### First boot and Imager

- Raspberry Pi Imager **2.0.12 or newer** (latest on 2026-10-08) is required.
  Imager 1.x silently fails to customise Trixie images.
- Imager does **not** offer customisation for an image chosen with "Use
  custom" (`init_format: none`; maintainers declined to change this,
  rpi-imager issue #1397). So each release publishes a manifest,
  `gbs-anywhere.rpi-imager-manifest` (Imager's JSON OS-list format, schema in
  rpi-imager `doc/json-schema/os-list-schema.json` at v2.0.12), with one OS
  entry:
  - `init_format: "cloudinit-rpi"` (what the official Trixie Lite entry uses);
  - `url` to that release's `.img.xz`, plus `extract_size`,
    `extract_sha256` (of the uncompressed image), `image_download_size`,
    `image_download_sha256`, `release_date`;
  - `devices` with the 64-bit tags the official Trixie Lite entry uses;
  - a top-level `imager.devices` block (Imager reads device tags only from
    there), taken from the official manifest
    (https://downloads.raspberrypi.com/os_list_imagingutility_v4.json);
  - name "gbs-anywhere", a description, and a generic icon (no logos).
- People open it with Imager by a link
  `rpi-imager://?repo=https://github.com/<owner>/gbs-anywhere-pi/releases/latest/download/gbs-anywhere.rpi-imager-manifest`
  (Imager asks to confirm), or by downloading the file and opening it, or
  under App Options → Content Repository. `releases/latest` never points at
  a pre-release, so it always serves the last image the owner approved.
- The image itself relies on what pi-gen's `stage2` already ships: Raspberry
  Pi's patched cloud-init with `rpi-cloud-init-mods`, NetworkManager via
  netplan, `raspberrypi-sys-mods`, `userconf-pi` and `avahi-daemon`
  (`<hostname>.local` works out of the box). We add nothing for this.
- The default hostname is `gbs-anywhere`. If the person picks another one in
  Imager, that wins, and the app is at `http://<that name>.local/`.
- If no user is set in Imager, Lite asks for one on an attached screen; the
  network and the app should still come up without it (to be confirmed on a
  real Pi).

### Setup hotspot (comitup)

- Install **comitup** from Debian Trixie's main archive (1.43-1 on
  2026-10-26). When the Pi has no Wi-Fi network it can join, comitup opens
  its own **open** Wi-Fi network; the person joins it on a phone, picks
  their home network and types its password on comitup's page, and the Pi
  switches over. The owner chose open over a shared password (see
  anti-goals); it exists only while the Pi has no network.
- `/etc/comitup.conf`: `ap_name: gbs-anywhere-<nnn>`, no `ap_password`,
  `web_service: gbs-anywhere.service`.
- With `web_service`, comitup stops gbs-anywhere while its hotspot is up and
  starts it once connected to Wi-Fi. This also avoids a port clash: comitup's
  page listens on `0.0.0.0:80`, as does gbs-anywhere. It means the app is
  never reachable over the open hotspot. comitup's docs require the
  `web_service` unit to be disabled in systemd, hence the disabled service
  above.
- **Wi-Fi must be set in Imager** (owner's choice). pi-gen at the pinned tag
  writes `WirelessEnabled=false` when `WPA_COUNTRY` is unset, and Raspberry
  Pi keeps the radio blocked until a Wi-Fi country is set; Imager sets the
  country along with the Wi-Fi details. So the hotspot rescues a wrong
  password or a changed network, not a Pi that never had Wi-Fi settings.
  The README says Wi-Fi in Imager is required (unless the Pi is on
  Ethernet). The image does not set a default or "world" country.
- **Ethernet.** comitup 1.43 only considers Wi-Fi: with a cable and no saved
  Wi-Fi it stays in hotspot mode forever and never starts gbs-anywhere. The
  owner wants Ethernet-only Pis supported, so this repo adds one small
  NetworkManager dispatcher script (about 15 lines): when a wired connection
  comes up, stop comitup (and its hotspot) and start gbs-anywhere. The exact
  behaviour when the cable goes away again is left to the builder, as long as
  the Pi ends up either on a network with the app running, or in the hotspot
  with the app stopped.
- To be confirmed on a real Pi: comitup sees the Wi-Fi network Imager
  configured (netplan-generated NetworkManager connections) and does not
  fight it; a wrong Wi-Fi password from Imager leads to the hotspot; comitup
  on Trixie works (comitup issue #269 reported a captive-portal detection
  problem, later closed as not reproducible).

### Network address and the E64 WS

- No static IP. The README leads with entering `gbs-anywhere.local` (or the
  chosen hostname) as the host in the E64 WS (**Edit Host**). Upstream's
  README says an IP is more reliable; the owner believes that came from the
  owner's own network. Whether the E64 WS resolves `.local` names is a real-Pi test.
- Fallback in the README, in plain words: if the grinder doesn't connect,
  enter the Pi's IP address instead, and reserve that address in the router
  ("address reservation" or "static lease"), using the Pi's name to find it.
- Whether the app, opened by name, shows the Pi's IP for the grinder is an
  upstream question; noted for the owner, nothing to build here.

### Updates

- This version: re-flash. The README says what re-flashing loses (the app's
  settings, shot history and E65/E80 pairing in `/var/lib/gbs-anywhere`) and
  what comes back (Wi-Fi and user via Imager). People comfortable with SSH can
  instead follow upstream's `sudo apt install ./gbs-anywhere_<v>-1_arm64.deb`.
- The app's own update check stays on (upstream default); it tells people a
  new version exists.

### Builds and releases

- One workflow, `ubuntu-24.04-arm`:
  - `pull_request`: build the image (and manifest) and keep them as workflow
    artifacts; publish nothing.
  - `repository_dispatch` (type e.g. `gbs-anywhere-release`, payload: the
    version) sent by upstream's release job, and `workflow_dispatch` with a
    version input: build, then create a public **pre-release** with the image,
    manifest, checksums, pi-gen's package list (`.info`) and SBOM attached.
  - The release is created in the same run, because a release made with the
    workflow's own token does not start other workflows.
- No scheduled polling (the owner wants builds only for new app releases; and
  GitHub disables schedules in public repos after 60 days of inactivity).
- The upstream change (a dispatch step with a token limited to this repo,
  *Contents: write*; a GitHub App token preferred over a fine-grained PAT) is
  made by the owner in upstream; this repo documents what it expects.
- Tags: `v<app version>-<build>`, starting at `-1` (e.g. `v0.3.1-1`); a
  rebuild of the same app version raises the build number. (Designer's
  call:) the workflow counts it itself: one more than the highest build
  number among this repo's releases for that app version, pre-releases
  included. A deleted pre-release frees its number.
- (Designer's call:) the version file is the pin for pull-request builds and
  the default for a manual run; a dispatch passes its version explicitly and
  the release notes record it. The workflow never writes to the repository;
  the owner bumps the version file in a pull request when convenient.
- Owner flow: pre-release appears → open its own manifest
  (`releases/download/<tag>/gbs-anywhere.rpi-imager-manifest`) in Imager,
  flash and test on a real Pi → turn it into a full release, which makes it
  `latest`. Pre-releases are publicly visible on GitHub but skipped by
  `releases/latest`, so novices never get an untested image. (Drafts were
  rejected: their files need a logged-in download, so Imager can't fetch
  the image from a draft's manifest.)

### Licensing and naming

- This repo's own files: **MIT** (owner's choice). If pi-gen code is copied,
  its BSD-3-Clause notice is kept with it.
- README "Licences" section: the image is a collection of separately
  licensed works (Debian, Raspberry Pi, gbs-anywhere, comitup), each under
  its own licence, listed in `/usr/share/doc/*/copyright` in the image
  (including Broadcom/Cypress firmware licences, which allow unmodified
  redistribution for use with that hardware); gbs-anywhere is
  AGPL-3.0-or-later, installed unmodified from the linked upstream tag, with
  its `.deb`'s SHA256; this repo is MIT. No source bundle or written offer
  (owner's choice for now).
- Trademarks: "based on Raspberry Pi OS Lite", "for Raspberry Pi"; never
  "Raspberry Pi OS" as the image's name. The line "Raspberry Pi is a
  trademark of Raspberry Pi Ltd", a not-affiliated note for Raspberry Pi Ltd,
  and upstream's "Not affiliated with Mahlkönig or Hemro".
- Don't strip `/usr/share/doc` from the image.

## Left to the builder

- Repo layout, script language (shell expected), how the pi-gen config is
  generated, and how the manifest is produced (e.g. `jq`).
- Whether the `imager.devices` block is fetched at build time or kept in the
  repo, and the exact device tags (match the official Trixie Lite entry).
- The dispatcher script's details and the cable-removed behaviour (within the
  rule above).
- The Imager icon (generic, no logos) and the exact README wording, as long
  as it is written for a novice and matches what the image does.
- Disk-space handling on the runner if the build runs out.

## Done means

- A CI build (or a local one on arm64 Linux) produces the image and manifest,
  and the build log can be shown.
- The owner, on a real Pi: Imager customisation works through the manifest;
  the Pi joins Wi-Fi; a wrong Wi-Fi password leads to the
  `gbs-anywhere-<nnn>` hotspot and setting Wi-Fi there works; Ethernet only
  works; `http://gbs-anywhere.local/` shows the app; `systemctl status
  gbs-anywhere` is active; SSH is off unless chosen; the E64 WS connects
  using `gbs-anywhere.local` (or the IP fallback).
- The README matches what the image actually does.
- Nothing is pushed, tagged or released without the owner's go-ahead.

## Later

- Signed apt repository on GitHub Pages so `apt upgrade` (and maybe
  unattended-upgrades) updates the app: Ed25519 key, offline primary, signing
  subkey in a protected GitHub environment, deb822 source with `Signed-By`,
  pinned to priority 100. Debian 13's apt (sqv) rejects SHA-1 signatures and,
  from 2030, RSA keys under 3072 bits.
- GPL source bundles per release, if the project grows.
- Novice video and wiki page.
