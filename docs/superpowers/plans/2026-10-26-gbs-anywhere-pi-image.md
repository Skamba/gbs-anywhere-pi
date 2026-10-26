# gbs-anywhere Pi image Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and publish a Raspberry Pi OS Lite (Trixie, arm64) image with one pinned gbs-anywhere release, an Imager manifest, a setup hotspot, and a README for novices.

**Architecture:** Small, tested shell scripts do the parts that can be tested off a Pi (download and checksum, build numbering, manifest, network glue). `scripts/build-image.sh` copies one custom pi-gen stage into a checkout of pi-gen at a pinned tag and runs pi-gen's `build-docker.sh`. One GitHub Actions workflow runs the tests, builds on `ubuntu-24.04-arm`, checks the built image by mounting it, and on a dispatch or manual run creates a public pre-release.

**Tech Stack:** bash, pi-gen (`2026-10-06-raspios-trixie-arm64`), Docker, jq, xz, bats-core and shellcheck for tests, GitHub Actions, NetworkManager dispatcher, systemd, comitup 1.43 (Debian Trixie).

**Spec:** `docs/superpowers/specs/2026-10-26-gbs-anywhere-pi-image-design.md`

## Global Constraints

- App: installed only from `https://github.com/Skamba/gbs-anywhere/releases/download/v<v>/gbs-anywhere_<v>-1_arm64.deb`, checked against that release's `SHA256SUMS`; never built or copied into this repo.
- pi-gen pinned to tag `2026-10-06-raspios-trixie-arm64`; stages `stage0 stage1 stage2` unchanged plus `stage-gbs`; only `stage-gbs` exports.
- pi-gen config: `RELEASE=trixie`, `TARGET_HOSTNAME=gbs-anywhere`, `DEPLOY_COMPRESSION=xz`, `ENABLE_CLOUD_INIT=1`, `ENABLE_SSH=0`, `FIRST_USER_PASS` unset, `DISABLE_FIRST_BOOT_USER_RENAME=0`, `WPA_COUNTRY` unset.
- No default password anywhere (user or hotspot). SSH off unless set in Imager.
- Names: tag `v<app version>-<build>` (e.g. `v0.3.1-1`); image `gbs-anywhere-<app version>-<build>-arm64.img.xz`; manifest `gbs-anywhere.rpi-imager-manifest`.
- Versions are `^[0-9]+\.[0-9]+\.[0-9]+$` and nothing else.
- Hotspot: comitup, `ap_name: gbs-anywhere-<nnn>`, open, `web_service: gbs-anywhere.service`; `gbs-anywhere.service` disabled at boot.
- Never "Raspberry Pi OS" as the image's name, never "Raspberry Pi" in repo or file names, no logos; README keeps "Not affiliated with Mahlkönig or Hemro" and "Raspberry Pi is a trademark of Raspberry Pi Ltd".
- Public wording per upstream AGENTS.md: English, no real IPs (examples like `192.168.1.20` only), hostnames, serials, account names or device logs.
- This repo's files: MIT. Shell scripts: `#!/usr/bin/env bash`, `set -euo pipefail`, LF line endings, executable bit set in git.
- Ask the owner before creating the GitHub repo, pushing, tagging or publishing. Once the workflow exists, its dispatch/manual runs may create pre-releases by themselves.

## Review Focus

1. **Untrusted version strings.** A `repository_dispatch` payload or manual input like `0.3.1; curl x|sh`, `v0.3.1` or `../0.3.1` must be refused before it reaches a shell command or URL. Tests in Task 2 (`fetch-deb.sh`, `next-build.sh`); the workflow passes inputs through `env:`, never `${{ }}` inside `run:` (Task 6).
2. **Windows checkout breaking scripts.** CRLF line endings or a lost executable bit make NetworkManager silently skip the dispatcher and break shebangs. `.gitattributes` forces LF (Task 1); a bats test fails on any CR in tracked text files (Task 1); `check-image.sh` checks the installed files' modes and owner (Task 5).
3. **Lookalike checksum lines.** `SHA256SUMS` holds several files; matching must be by exact filename, so `gbs-anywhere_0.3.1-1_arm64.deb.sig` or `…_amd64.deb` never satisfies the check. Test in Task 2.
4. **Cable events.** Unplugging Ethernet while a second wired link or Wi-Fi is up, or at shutdown, must not hang the dispatcher or bring up the hotspot needlessly. `--no-block` everywhere and a test for "other wired link still connected" in Task 4.
5. **Version prefix collisions in build numbering.** Building `0.3.1` when `v0.3.10-4` and `v0.3.1-2` exist must give `3`, not `5`. Test in Task 2.

---

## File Structure

```
.gitattributes, .gitignore, LICENSE (MIT), README.md
GBS_ANYWHERE_VERSION            0.3.1
PI_GEN_TAG                      2026-10-06-raspios-trixie-arm64
scripts/
  lib.sh                        valid_version()
  fetch-deb.sh                  download + verify the .deb
  next-build.sh                 next build number from a list of tags
  make-manifest.sh              Imager manifest JSON
  release-notes.sh              release notes markdown
  build-image.sh                pi-gen checkout, config, build
  check-image.sh                mount the built image and check it (root)
stage-gbs/                      pi-gen stage, copied into the pi-gen checkout
  prerun.sh, EXPORT_IMAGE
  00-gbs-anywhere/00-run.sh, 01-run-chroot.sh   (files/ filled at build time)
  01-setup-hotspot/00-packages, 01-run.sh
  01-setup-hotspot/files/comitup.conf
  01-setup-hotspot/files/gbs-anywhere-net
  01-setup-hotspot/files/50-gbs-anywhere-wired
  01-setup-hotspot/files/comitup-gbs-anywhere.conf
imager/icon.png                 64x64 generic glyph, no logos
test/*.bats, test/fixtures/
.github/workflows/build.yml
```

Local test runs use WSL (`Ubuntu-24.04`), which needs `bats shellcheck jq` installed once. Ask the owner to run `! wsl -d Ubuntu-24.04 -- sudo apt-get install -y bats shellcheck jq`. Run tests with `wsl -d Ubuntu-24.04 -- bats test/` from the repo folder. The image itself only builds in CI (arm64).

---

### Task 1: Repository skeleton

**Files:**
- Create: `.gitattributes`, `.gitignore`, `LICENSE`, `GBS_ANYWHERE_VERSION`, `PI_GEN_TAG`, `scripts/lib.sh`, `test/repo.bats`, `test/lib.bats`

**Interfaces:**
- Produces: `scripts/lib.sh`, sourced by other scripts, defining `valid_version VERSION` (returns 0 if it matches `^[0-9]+\.[0-9]+\.[0-9]+$`, else prints `invalid version: <v>` to stderr and returns 1) and `die MESSAGE` (prints to stderr, exits 1).

- [ ] **Step 1:** `git init -b main` in `C:\Coding\gbs-anywhere-pi` (local only; the design doc and this plan are already in `docs/`).
- [ ] **Step 2: Write the failing tests.** `test/repo.bats`: `@test "no CR in tracked text files"` runs `git ls-files --eol` and fails if any line shows `i/crlf` or `w/crlf`; `@test "scripts are executable in git"` checks `git ls-files -s scripts/*.sh stage-gbs` mode `100755` for every `*.sh`, `gbs-anywhere-net` and `50-gbs-anywhere-wired` (skip names not yet present). `test/lib.bats`: `valid_version 0.3.1` → 0; `10.20.30` → 0; each of `v0.3.1`, `0.3`, `0.3.1-1`, `0.3.1; true`, `../0.3.1`, empty → 1.
- [ ] **Step 3:** Run `wsl -d Ubuntu-24.04 -- bats test/`. Expected: `lib.bats` fails (no `scripts/lib.sh`).
- [ ] **Step 4: Implement.** `.gitattributes`: `* text=auto eol=lf` and `*.png binary`. `.gitignore`: `/build/`, `/deploy/`, `/pi-gen/`. `LICENSE`: MIT, "Copyright 2026 Skamba and the gbs-anywhere-pi contributors". `GBS_ANYWHERE_VERSION`: `0.3.1`. `PI_GEN_TAG`: `2026-10-06-raspios-trixie-arm64`. `scripts/lib.sh` as in Interfaces.
- [ ] **Step 5:** Run `bats test/` and `shellcheck scripts/*.sh` in WSL. Expected: all pass, no shellcheck findings.
- [ ] **Step 6: Commit.** `git add -A && git commit -m "Add repository skeleton and shared shell helpers"` (body: why, plus the attribution lines).

### Task 2: Download check and build numbering

**Files:**
- Create: `scripts/fetch-deb.sh`, `scripts/next-build.sh`, `test/fetch-deb.bats`, `test/next-build.bats`, `test/fixtures/release/` (made by the test's `setup`)

**Interfaces:**
- Consumes: `valid_version`, `die` from `scripts/lib.sh`.
- Produces:
  - `scripts/fetch-deb.sh VERSION OUTDIR` — downloads `gbs-anywhere_<v>-1_arm64.deb` and `SHA256SUMS` from `${GBS_RELEASE_BASE_URL:-https://github.com/Skamba/gbs-anywhere/releases/download}/v<v>/` into `OUTDIR` with `curl -fsSL`, verifies, prints the `.deb`'s absolute path on stdout, exit 0. On any failure: non-zero, nothing left at the `.deb` path.
  - `scripts/next-build.sh VERSION` — reads tags (one per line) on stdin, prints the next build number.

- [ ] **Step 1: Write the failing tests.** `test/fetch-deb.bats`, with `setup` creating a fake release dir (a small file named `gbs-anywhere_0.3.1-1_arm64.deb` and a matching `SHA256SUMS` with lines for it plus an amd64 lookalike) and `GBS_RELEASE_BASE_URL=file://<dir>`:
  - "good checksum": exit 0, stdout is `<OUTDIR>/gbs-anywhere_0.3.1-1_arm64.deb`, file exists.
  - "mismatched checksum": edit the `.deb` after writing `SHA256SUMS`, exit ≠ 0, no `.deb` in OUTDIR.
  - "only a lookalike line": `SHA256SUMS` has the right hash but for `gbs-anywhere_0.3.1-1_arm64.deb.sig`, exit ≠ 0.
  - "missing release": version `9.9.9`, exit ≠ 0.
  - "invalid version": `0.3.1;true` and `v0.3.1`, exit ≠ 0 and stderr contains `invalid version`, and no download is attempted (point the base URL at a dir that doesn't exist and assert the message is `invalid version`, not a curl error).

  `test/next-build.bats`:
  - empty stdin, `0.3.1` → `1`
  - `v0.3.1-1\nv0.3.1-2` → `3`
  - `v0.3.10-4\nv0.3.1-2\nv0.3.1-x\nv0.3.1` → `3`
  - `v0.3.1-1\nv0.3.1-5` → `6`
  - `0.3.1;true` → exit ≠ 0
- [ ] **Step 2:** Run `bats test/fetch-deb.bats test/next-build.bats`. Expected: FAIL (scripts missing).
- [ ] **Step 3: Implement both scripts.** `fetch-deb.sh`: download into a temp dir inside OUTDIR, pick the line whose second field equals the exact filename (`awk '$2 == f || $2 == "*" f'`), require exactly one, check with `sha256sum -c`, then `mv` into place. `next-build.sh`: match `^v<escaped version>-([0-9]+)$` exactly, print max+1 (1 when none).
- [ ] **Step 4:** Run `bats test/` and `shellcheck scripts/*.sh`. Expected: all pass.
- [ ] **Step 5: Commit** "Add checked .deb download and build numbering".

### Task 3: Imager manifest and release notes

**Files:**
- Create: `scripts/make-manifest.sh`, `scripts/release-notes.sh`, `imager/icon.png`, `test/make-manifest.bats`, `test/release-notes.bats`, `test/fixtures/os_list.json`

**Interfaces:**
- Produces:
  - `scripts/make-manifest.sh --image PATH.img.xz --tag TAG --repo OWNER/NAME --date YYYY-MM-DD --official OS_LIST.json` → manifest JSON on stdout.
  - `scripts/release-notes.sh --version V --tag TAG --deb-sha256 HEX --pi-gen-tag T --repo OWNER/NAME` → markdown on stdout.

The manifest must be exactly this shape (values computed, `<…>` filled):

```json
{
  "imager": { "devices": <.imager.devices of the official list> },
  "os_list": [{
    "name": "gbs-anywhere",
    "description": "gbs-anywhere <version> on Raspberry Pi OS Lite (64-bit). Grind-by-Sync for Mahlkönig grinders with any espresso machine.",
    "icon": "https://github.com/<repo>/releases/download/<tag>/gbs-anywhere-icon.png",
    "url": "https://github.com/<repo>/releases/download/<tag>/<image file name>",
    "extract_size": <bytes of the uncompressed image>,
    "extract_sha256": "<sha256 of the uncompressed image>",
    "image_download_size": <bytes of the .img.xz>,
    "image_download_sha256": "<sha256 of the .img.xz>",
    "release_date": "<date>",
    "init_format": "cloudinit-rpi",
    "devices": <devices of the official "Raspberry Pi OS Lite (64-bit)" entry>,
    "capabilities": <capabilities of that entry>,
    "website": "https://github.com/<repo>"
  }]
}
```

The `<version>` comes from the tag (`v0.3.1-1` → `0.3.1`). The official entry is found anywhere in the tree with `jq '.. | objects | select(.name? == "Raspberry Pi OS Lite (64-bit)")'`. Exactly one must match, else the script fails. That entry today: `devices ["pi5-64bit","pi4-64bit","pi3-64bit"]`, `capabilities ["rpi_connect"]`, `init_format "cloudinit-rpi"`. Also fail if the official entry's `init_format` is not `cloudinit-rpi`: that means Raspberry Pi changed the format and the image needs a look.

- [ ] **Step 1: Write the failing tests.** Fixture `test/fixtures/os_list.json`: a trimmed copy of the official list (top-level `imager.devices` with two devices; `os_list` with a nested "Raspberry Pi OS (other)" → "Raspberry Pi OS Lite (64-bit)" entry carrying the values above, and one unrelated entry). In `setup`, make a 3 MiB file of random bytes and `xz` it to `gbs-anywhere-0.3.1-1-arm64.img.xz`. Tests:
  - "fields": `init_format == "cloudinit-rpi"`, `name == "gbs-anywhere"`, `url == "https://github.com/Skamba/gbs-anywhere-pi/releases/download/v0.3.1-1/gbs-anywhere-0.3.1-1-arm64.img.xz"`, `devices == ["pi5-64bit","pi4-64bit","pi3-64bit"]`, `capabilities == ["rpi_connect"]`, `imager.devices` equals the fixture's, and the description contains `0.3.1`.
  - "sizes and hashes": `extract_size == 3145728`; `extract_sha256` equals `sha256sum` of the raw file; `image_download_size` and `image_download_sha256` match the `.xz`.
  - "official entry missing": fixture without it → exit ≠ 0.
  - "official format changed": fixture with `init_format: "rpi-preseed"` → exit ≠ 0.
  - release notes: output contains `https://github.com/Skamba/gbs-anywhere/releases/tag/v0.3.1`, the deb sha256, the pi-gen tag, the manifest link `https://github.com/Skamba/gbs-anywhere-pi/releases/download/v0.3.1-1/gbs-anywhere.rpi-imager-manifest`, "Raspberry Pi is a trademark of Raspberry Pi Ltd", and "Not affiliated with Mahlkönig or Hemro".
- [ ] **Step 2:** Run `bats test/make-manifest.bats test/release-notes.bats`. Expected: FAIL.
- [ ] **Step 3: Implement.** Use `jq -n` with `--arg`/`--argjson`, `xz -dc | sha256sum`, `xz -dc | wc -c`, and `stat -c %s`. Release notes cover: what's in it (app version linked to the upstream tag, `.deb` sha256, based on Raspberry Pi OS Lite via pi-gen tag), how to use it (Imager 2.0.12 or newer, open the manifest link), "pre-release: not tested yet" until the owner promotes it (a sentence the owner deletes on promotion), and the licence notes from the spec. Make `imager/icon.png`: 64×64 PNG, a plain generic glyph (e.g. a circle with two arrows meaning "sync"), no logos, made with any tool. Keep the source of the glyph out of the repo unless it is a small SVG next to it.
- [ ] **Step 4:** Run `bats test/` and `shellcheck`. Expected: all pass.
- [ ] **Step 5: Commit** "Add Imager manifest and release notes generators".

### Task 4: Network glue (setup hotspot and Ethernet)

**Files:**
- Create: `stage-gbs/01-setup-hotspot/files/gbs-anywhere-net`, `.../files/50-gbs-anywhere-wired`, `.../files/comitup.conf`, `.../files/comitup-gbs-anywhere.conf`, `test/net.bats`

**Interfaces:**
- Produces, as installed in the image (Task 5 installs them):
  - `/usr/lib/gbs-anywhere-pi/gbs-anywhere-net no-wired` exits 0 when no Ethernet device is connected (comitup may run), and 1 when one is. If `nmcli` fails, it exits 0.
  - `/usr/lib/gbs-anywhere-pi/gbs-anywhere-net dispatch IFACE ACTION` is the NetworkManager dispatcher logic. It always exits 0.
  - `/etc/NetworkManager/dispatcher.d/50-gbs-anywhere-wired` is two lines: `#!/bin/sh` and `exec /usr/lib/gbs-anywhere-pi/gbs-anywhere-net dispatch "$@"`.
  - `/etc/systemd/system/comitup.service.d/gbs-anywhere.conf`: `[Service]` / `ExecCondition=/usr/lib/gbs-anywhere-pi/gbs-anywhere-net no-wired`.
  - `/etc/comitup.conf`: exactly three settings, `ap_name: gbs-anywhere-<nnn>`, `web_service: gbs-anywhere.service`, `enable_appliance_mode: false`, each with a one-line comment saying why. No `ap_password`.

Dispatcher rules. "Wired" means `nmcli -t -f TYPE,STATE device` has a line `ethernet:connected`. The interface type comes from `nmcli -g GENERAL.TYPE device show IFACE`.
- `up` on an ethernet IFACE runs `systemctl --no-block stop comitup.service comitup-web.service`, then `systemctl --no-block start gbs-anywhere.service`.
- `down` on an ethernet IFACE, when no other wired connection is left, runs `systemctl --no-block start comitup.service`. comitup then either connects to Wi-Fi, which starts the app, or opens the hotspot, which stops it. If another wired connection is still up, it does nothing.
- Anything else (wifi, other actions, unknown types) does nothing.

- [ ] **Step 1: Write the failing tests** in `test/net.bats`. Put stub `nmcli` and `systemctl` scripts first on `PATH`. The `nmcli` stub prints canned output from env vars (`STUB_DEVICES`, `STUB_TYPE`) or fails when `STUB_NMCLI_FAIL=1`. The `systemctl` stub appends its arguments to `$BATS_TEST_TMPDIR/calls`. Cases:
  - `no-wired` with `ethernet:connected` → 1; with `ethernet:unavailable\nwifi:connected` → 0; with nmcli failing → 0.
  - `dispatch eth0 up` (type ethernet) → calls are exactly `--no-block stop comitup.service comitup-web.service` then `--no-block start gbs-anywhere.service`.
  - `dispatch wlan0 up` (type wifi) → no calls.
  - `dispatch eth0 down`, devices `ethernet:unavailable\nwifi:connected` → exactly `--no-block start comitup.service`.
  - `dispatch eth0 down`, devices still contain `ethernet:connected` (a second port) → no calls.
  - `dispatch eth0 dhcp4-change` → no calls; exit 0 in every case, also when `systemctl` fails.
- [ ] **Step 2:** Run `bats test/net.bats`. Expected: FAIL.
- [ ] **Step 3: Implement** `gbs-anywhere-net` (bash, about 40 lines) and the three config files above.
- [ ] **Step 4:** Run `bats test/` and `shellcheck` (include `gbs-anywhere-net`; `50-gbs-anywhere-wired` with `-s sh`). Set the executable bits in git with `git update-index --chmod=+x` for both scripts. Expected: all pass, including `repo.bats`.
- [ ] **Step 5: Commit** "Add setup hotspot config and Ethernet handling".

### Task 5: pi-gen stage, image build and image check

**Files:**
- Create: `stage-gbs/prerun.sh`, `stage-gbs/EXPORT_IMAGE`, `stage-gbs/00-gbs-anywhere/00-run.sh`, `stage-gbs/00-gbs-anywhere/01-run-chroot.sh`, `stage-gbs/01-setup-hotspot/00-packages`, `stage-gbs/01-setup-hotspot/01-run.sh`, `scripts/build-image.sh`, `scripts/check-image.sh`, `test/build-image.bats`

**Interfaces:**
- Consumes: `fetch-deb.sh` (Task 2), the Task 4 files.
- Produces:
  - `scripts/build-image.sh VERSION BUILD` builds in `./build/`. It writes the image, `.info` and (if pi-gen made one) `.sbom.xz` to `./deploy/`, all named `gbs-anywhere-<v>-<b>-arm64.*`, and prints the image path last. It needs Docker and an arm64 host.
  - `scripts/build-image.sh --config-only VERSION BUILD OUTFILE` writes only the pi-gen config, so it can be tested.
  - `sudo scripts/check-image.sh IMAGE.img.xz VERSION` exits 0 when every check passes and prints one line per check.

Stage contents:
- `prerun.sh` is the same as pi-gen's `stage2/prerun.sh` (`copy_previous` when the rootfs is missing).
- `EXPORT_IMAGE` is `IMG_SUFFIX=""`.
- `00-run.sh` installs `files/gbs-anywhere.deb` to `${ROOTFS_DIR}/tmp/gbs-anywhere.deb`.
- `01-run-chroot.sh` runs `apt-get install -y /tmp/gbs-anywhere.deb`, `rm /tmp/gbs-anywhere.deb` and `systemctl disable gbs-anywhere.service`.
- `00-packages` is `comitup`.
- `01-run.sh` installs the Task 4 files: `gbs-anywhere-net` at `0755`, the dispatcher at `0755` (root-owned, as NetworkManager requires), and the rest at `0644`.

`build-image.sh` steps:
1. Validate the inputs.
2. `git clone --depth 1 --branch "$(cat PI_GEN_TAG)" https://github.com/RPi-Distro/pi-gen.git build/pi-gen`.
3. `fetch-deb.sh` into `build/pi-gen/stage-gbs/00-gbs-anywhere/files/gbs-anywhere.deb` after copying `stage-gbs/` over.
4. `touch build/pi-gen/stage2/SKIP_IMAGES`.
5. Write the config.
6. Run `./build-docker.sh -c <config>` inside `build/pi-gen`.
7. Move the outputs from `build/pi-gen/deploy/` into `./deploy/`, together with `build-docker.log` and `build.log`.

The config is exactly:

```sh
IMG_NAME=gbs-anywhere
IMG_FILENAME=gbs-anywhere-<v>-<b>-arm64
ARCHIVE_FILENAME=gbs-anywhere-<v>-<b>-arm64
RELEASE=trixie
TARGET_HOSTNAME=gbs-anywhere
DEPLOY_COMPRESSION=xz
ENABLE_CLOUD_INIT=1
ENABLE_SSH=0
DISABLE_FIRST_BOOT_USER_RENAME=0
STAGE_LIST="stage0 stage1 stage2 stage-gbs"
PI_GEN_RELEASE="gbs-anywhere <v>-<b> (based on Raspberry Pi OS Lite)"
```

`check-image.sh` decompresses the image to a temp file, attaches it with `losetup -P`, mounts p2 (root) and p1 (boot) read-only, checks the items below, and always cleans up through a trap:
- `/usr/bin/gbs-anywhere` exists, and `dpkg-query -W gbs-anywhere --admindir <root>/var/lib/dpkg` reports `<v>-1`.
- `gbs-anywhere.service` is not enabled: there is no `multi-user.target.wants/gbs-anywhere.service` link.
- `comitup.service` is enabled.
- `/etc/comitup.conf` contains `web_service: gbs-anywhere.service` and no `ap_password`.
- The dispatcher and `gbs-anywhere-net` have mode 755, uid 0 and no CR bytes.
- The `comitup.service.d` drop-in exists.
- `/etc/hostname` is `gbs-anywhere`.
- `ssh.service` is not enabled.
- No account in `/etc/shadow` has a usable password: every second field is `!`, `*`, or starts with `!`.
- `/var/lib/cloud` is absent or empty.
- `cloud-init` and `rpi-cloud-init-mods` are installed.
- `/boot/firmware` (p1) holds the cloud-init seed files pi-gen ships.
- `/usr/share/doc/gbs-anywhere/copyright` exists.

- [ ] **Step 1: Write the failing test** `test/build-image.bats`. `--config-only 0.3.1 1 $tmp/config` writes exactly the config above with `<v>-<b>` = `0.3.1-1`. `--config-only 'x;y' 1 …` and `--config-only 0.3.1 0 …` both exit ≠ 0, because the build must be a positive integer.
- [ ] **Step 2:** Run it; expect FAIL.
- [ ] **Step 3: Implement** the stage files, `build-image.sh` and `check-image.sh`. Mark every script executable in git.
- [ ] **Step 4:** Run `bats test/` and `shellcheck` on all scripts. Expected: pass. (A real build and image check happen in Task 6 on CI.)
- [ ] **Step 5: Commit** "Add pi-gen stage, image build and image check".

### Task 6: GitHub Actions workflow and first CI build

**Files:**
- Create: `.github/workflows/build.yml`

**Interfaces:**
- Consumes: every script above.
- Produces: the events and payload upstream relies on: `repository_dispatch` with `event_type: gbs-anywhere-release` and `client_payload: {"version": "X.Y.Z"}`.

Workflow:
- **Triggers:**
  - `push` (branch `main`) and `pull_request`: test and build, publish nothing.
  - `workflow_dispatch` with input `version` (optional; default from `GBS_ANYWHERE_VERSION`).
  - `repository_dispatch` of type `gbs-anywhere-release`.
- **Defaults:** `permissions: contents: read` at the top. `concurrency: image-${{ github.ref }}`; for dispatch events, group on the version instead.
- **Job `test`** (`ubuntu-24.04`): `apt-get install bats shellcheck jq`, then `bats test/`, then `shellcheck` on every script.
- **Job `image`** (`ubuntu-24.04-arm`, `needs: test`, `timeout-minutes: 120`):
  1. Resolve the version from the payload, the input or the file. It goes through `env:` only, then `valid_version`.
  2. Work out the build number by piping `gh release list --limit 1000 --json tagName --jq '.[].tagName'` into `next-build.sh`, with `GH_TOKEN: ${{ github.token }}`.
  3. `df -h` before and after the build.
  4. Run `scripts/build-image.sh`, then `sudo scripts/check-image.sh`.
  5. Fetch `https://downloads.raspberrypi.com/os_list_imagingutility_v4.json` and run `make-manifest.sh` with `--repo ${{ github.repository }}` and today's UTC date.
  6. `release-notes.sh`.
  7. Upload `deploy/*` and the manifest as a workflow artifact (`retention-days: 7`). This happens on every run, including pull requests.
- **Job `release`** (`ubuntu-24.04`, `needs: image`, `if:` the event is `workflow_dispatch` or `repository_dispatch`, `permissions: contents: write`): download the artifact, copy `imager/icon.png` to `gbs-anywhere-icon.png`, and run `gh release create v<v>-<b> --prerelease --target "$GITHUB_SHA" --title "gbs-anywhere <v> image (build <b>)" --notes-file notes.md`. Attach the `.img.xz`, the manifest, `gbs-anywhere-icon.png`, the `.info`, the `.sbom.xz` if present, and `SHA256SUMS` made over those files. The image and build number come from the `image` job's outputs.
- **Rules for every step:** no `${{ }}` expressions inside `run:` scripts. Pass them as `env:`. Pin actions to full commit SHAs, with the version in a comment.

- [ ] **Step 1: Write the workflow.** Check it with `actionlint` if it's available (`wsl -- go run github.com/rhysd/actionlint/cmd/actionlint@latest` or the Docker image). Otherwise review it by hand against the rules above.
- [ ] **Step 2: Commit** "Add build and release workflow".
- [ ] **Step 3: STOP and ask the owner** to create the public repo `Skamba/gbs-anywhere-pi` and push `main`. Only do it after an explicit yes.
- [ ] **Step 4:** Once pushed, watch the `push` run with `gh run watch`. Expected: `test` passes, and `image` builds, passes `check-image.sh` and uploads the artifact. Save the run URL and the `df -h` and build-time lines for the owner. Fix failures with `superpowers:systematic-debugging`, on a branch with a PR.
- [ ] **Step 5: STOP and ask the owner** before the first manual run, which creates a public pre-release: `gh workflow run build.yml -f version=0.3.1`. Expected: pre-release `v0.3.1-1` with its six or seven assets. Its manifest URL loads in Imager.

### Task 7: README and upstream hand-off

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: the names, links and behaviour from Tasks 3–6. The README describes only what those tasks built.

Sections, written for a novice, in plain sentences:
1. **What this is.** One paragraph, plus "Not affiliated with Mahlkönig or Hemro."
2. **What you need.** A Raspberry Pi 3, 4, 5 or Zero 2 W (or a 400/500), a microSD card of 8 GB or more, a power supply, a computer with Raspberry Pi Imager **2.0.12 or newer**, and your Wi-Fi name and password.
3. **Flash the card:**
   - Download the manifest from `https://github.com/Skamba/gbs-anywhere-pi/releases/latest/download/gbs-anywhere.rpi-imager-manifest` and open it with Imager. Alternatively, paste that URL under App Options → Content Repository.
   - Choose the Pi, then "gbs-anywhere", then the card.
   - In the settings, **set Wi-Fi (required unless the Pi uses a network cable)**, set a user and password, keep the hostname `gbs-anywhere`, and leave SSH off unless you want it.
   - Explain why "Use custom" won't do: it skips these settings.
4. **First start.** Wait a few minutes, then open `http://gbs-anywhere.local/` on the phone. If you changed the hostname, use `http://<hostname>.local/`.
5. **If the Pi doesn't join your Wi-Fi.** Join the open Wi-Fi network `gbs-anywhere-<number>` on your phone, choose your home network on the page that opens, and enter its password. The app isn't reachable while that setup network is up. A network cable also works, with no setup.
6. **Set up the E64 WS.** Under Edit Host, enter `gbs-anywhere.local`. If the grinder doesn't connect, use the Pi's IP address (shown in your router's device list, e.g. `192.168.1.20`) and reserve it in the router ("address reservation" or "static lease"). Then follow upstream's E64 WS steps, with a link to upstream's README section. E65/E80 users get a link to upstream.
7. **Updating.** Flash the newer image. Say what is lost (the app's settings, shot history and E65/E80 pairing) and what returns through Imager. With SSH: `sudo apt install ./gbs-anywhere_<version>-1_arm64.deb`. The app tells you when a new version exists.
8. **What the image changes.** Compared with Raspberry Pi OS Lite: the hostname, gbs-anywhere (started by the network setup, not at boot), comitup and its config, the Ethernet hook. Nothing else. No password, SSH off.
9. **For maintainers:**
   - How releases work: a dispatch or manual run creates a pre-release; test it, then mark it as the latest release.
   - The dispatch upstream sends: event type and payload, plus a token with *Contents: write* on this repo only (a GitHub App token preferred).
   - How to move to a new pi-gen tag.
   - How to run the tests.
10. **Licences.** The text agreed in the spec: an aggregate of separately licensed works, `/usr/share/doc/*/copyright`, firmware terms, gbs-anywhere AGPL-3.0-or-later linked to its tag, this repo MIT, the trademark line, not affiliated with Raspberry Pi Ltd, "based on Raspberry Pi OS Lite".

- [ ] **Step 1: Write `README.md`.** Run the `humanizer` skill over it for plain wording. Then check the wording rules: no real IPs or names, and no "Raspberry Pi OS" used as this image's name (grep for it).
- [ ] **Step 2:** Compare every claim with the scripts and config: hostname, hotspot name, file names, Imager version, what's disabled. Fix any mismatch in the README.
- [ ] **Step 3: Commit** "Add README for flashing, first start and updates". Push only with the owner's go-ahead, on a branch through a PR if `main` is protected by then.
- [ ] **Step 4: Hand off to the owner:**
  - the real-Pi test list from the spec's "Done means";
  - the upstream dispatch snippet to add to upstream's release job;
  - the open upstream question: does the app show the Pi's IP when it's opened by name?
