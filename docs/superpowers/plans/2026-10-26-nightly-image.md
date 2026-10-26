# Nightly Pi Image Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A daily pre-release image built from gbs-anywhere `main`, with the `.deb` built here by upstream's own packaging script, keeping the newest 7.

**Architecture:** A second workflow, `nightly.yml`, reuses the mainline scripts. Small helpers name the nightly and pick old ones to delete; `build-image.sh`, `check-image.sh` and `make-manifest.sh` learn a nightly mode, and `nightly-notes.sh` writes its notes. Mainline behaviour is unchanged.

**Tech Stack:** bash, bats, jq, shellcheck, actionlint, GitHub Actions, Docker `rust:1-bookworm`, cargo-deb 3.8.0 (`--deb-version`), pi-gen.

**Spec:** `docs/superpowers/specs/2026-10-26-nightly-image-design.md` (extends `2026-10-26-gbs-anywhere-pi-image-design.md`)

## Global Constraints

- Mainline (`build.yml`, `v<app>-<build>` tags, `fetch-deb.sh`) behaves exactly as before; every existing test still passes unchanged.
- Package version `X.Y.Z+gitYYYYMMDD.<sha7>` (deb `…-1`); tag `nightly-YYYYMMDD-<sha7>`; image `gbs-anywhere-nightly-YYYYMMDD-<sha7>-arm64.img.xz`; manifest file `gbs-anywhere-nightly.rpi-imager-manifest`; OS name `gbs-anywhere (nightly)`. Date is the upstream commit's date (UTC).
- Upstream `Cargo.toml` version must be plain `X.Y.Z`, else the build fails.
- Never copy upstream files into this repo; check upstream out at build time only (`/upstream/` is git-ignored).
- Nightlies are pre-releases, never latest. Keep the newest 7 nightly releases by creation time; delete older ones with `--cleanup-tag`; never touch any other release.
- Schedule `17 4 * * *`; skip when a release tag for upstream `main`'s commit already exists.
- Workflow rules as in `build.yml`: inputs only through `env:`, no `${{ }}` inside `run:`, actions pinned by the same SHAs, `permissions: contents: read` except the release job.
- Public wording rules and trademark lines as in the README; never call the image "Raspberry Pi OS".

## Review Focus

1. **Untrusted strings from the GitHub API and upstream's tree.** The commit SHA, its date and the `Cargo.toml` version reach tags, file names and shell commands; anything not matching its exact pattern is refused. Tests in Task 1.
2. **Pruning deletes the wrong release.** Only tags matching `^nightly-[0-9]{8}-[0-9a-f]{7}$` beyond the newest 7 are printed; `v0.3.1-1`, `nightly-foo` and an empty list print nothing. Tests in Task 1.
3. **`Cargo.toml` with other `version =` lines** (dependencies in inline tables, `[workspace.package]`) or a pre-release version such as `0.4.0-dev`: the package version is the first top-level `version = "…"` line, as upstream's script reads it, and a non-`X.Y.Z` value fails. Tests in Task 1.
4. **The same commit built twice** (cron and a manual run, or two days without upstream commits): the run stops before building. The check matches the whole tag line against `^nightly-[0-9]{8}-<sha7>$` for the current commit, so no other nightly can match by substring. Workflow, Task 4; reviewed by hand.
5. **The `.deb` path cargo-deb writes** for a version containing `+`: `target/debian/gbs-anywhere_<version>-1_arm64.deb`. Only the first CI build proves it; the workflow fails clearly (`build-image.sh` checks the file exists) rather than shipping a mainline-versioned package. Task 2 test for the missing-file refusal.

---

### Task 1: Nightly names and pruning helpers

**Files:**
- Modify: `scripts/lib.sh`
- Create: `scripts/nightly-info.sh`, `scripts/old-nightlies.sh`
- Test: `test/lib.bats`, `test/nightly-info.bats`, `test/old-nightlies.bats`

**Interfaces:**
- Produces: `valid_nightly_stamp STAMP` (`^[0-9]{8}-[0-9a-f]{7}$`) and `valid_package_version V` (mainline `X.Y.Z` or `X.Y.Z+gitYYYYMMDD.<sha7>`) in `lib.sh`, both printing `invalid …` to stderr and returning 1 on failure.
- Produces: `nightly-info.sh CARGO_TOML COMMIT_SHA COMMIT_DATE` → four lines `stamp=…`, `version=…`, `tag=nightly-…`, `name=gbs-anywhere-nightly-…-arm64`. COMMIT_SHA must be 40 lowercase hex, COMMIT_DATE ISO 8601 UTC (`2026-10-26T07:12:00Z`).
- Produces: `old-nightlies.sh KEEP` reads tags newest first on stdin, prints nightly tags past the first KEEP nightly ones.

- [ ] **Step 1: Write the failing tests**
  - `lib.bats`: `valid_nightly_stamp` accepts `20261026-abc1234`; refuses `2026102-abc1234`, `20261026-ABC1234`, `20261026-abc123`, `20261026-abc1234;x`, newline-joined values. `valid_package_version` accepts `0.3.1` and `0.3.1+git20261026.abc1234`; refuses `0.3.1+git2026.abc1234`, `0.3.1~rc1`, `0.3.1+git20261026.abc1234-1`.
  - `nightly-info.bats` with a `Cargo.toml` fixture written in the test (`[package]`, `name = "gbs-anywhere"`, `version = "0.3.1"`, then `[dependencies]` with `serde = { version = "1.0.200" }` and a later line `version = "9.9.9"` under `[workspace.package]`): output equals exactly
    `stamp=20261026-0123abc`, `version=0.3.1+git20261026.0123abc`, `tag=nightly-20261026-0123abc`, `name=gbs-anywhere-nightly-20261026-0123abc-arm64` for SHA `0123abc` + 33 more hex and date `2026-10-26T23:59:59Z`. Refused (non-zero): version `0.4.0-dev`; no version line; SHA of 39 chars or upper case; date `2026-10-26` without time or `26-10-2026T00:00:00Z`; a missing file.
  - `old-nightlies.bats`: 9 nightly tags newest first, mixed with `v0.3.1-1` and `nightly-foo` → `old-nightlies.sh 7` prints exactly the 8th and 9th nightly tags; 3 tags → nothing; empty input → nothing, status 0; `KEEP` of `0`, `x` or missing → non-zero.
- [ ] **Step 2: Run `bats test/lib.bats test/nightly-info.bats test/old-nightlies.bats`.** Expected: the new tests FAIL (functions and scripts missing); existing lib tests pass.
- [ ] **Step 3: Implement.** `nightly-info.sh` reads the first line matching `^version = "` like upstream's `grep -m 1 '^version = '`; date part is `${date:0:4}${date:5:2}${date:8:2}` after the full-pattern check; it validates its own outputs with `valid_nightly_stamp`/`valid_package_version`. Mark both scripts executable (`git update-index --chmod=+x`).
- [ ] **Step 4: Run the whole suite.** Expected: all pass; shellcheck clean.
- [ ] **Step 5: Commit** "Add nightly naming and pruning helpers".

### Task 2: Nightly mode for building and checking the image

**Files:**
- Modify: `scripts/build-image.sh`, `scripts/check-image.sh`, `.gitignore`
- Test: `test/build-image.bats`

**Interfaces:**
- Consumes: `valid_nightly_stamp`, `valid_package_version` (Task 1).
- Produces: `build-image.sh --nightly STAMP DEB` (uses DEB instead of `fetch-deb.sh`; image `gbs-anywhere-nightly-STAMP-arm64`) and `build-image.sh --config-only --nightly STAMP OUTFILE`. `check-image.sh IMAGE PACKAGE_VERSION` accepts either version form and expects package version `<PACKAGE_VERSION>-1`.

- [ ] **Step 1: Write the failing tests** in `build-image.bats`:
  - `--config-only --nightly 20261026-0123abc OUT` writes the mainline config with `IMG_FILENAME`/`ARCHIVE_FILENAME` `gbs-anywhere-nightly-20261026-0123abc-arm64` and `PI_GEN_RELEASE="gbs-anywhere nightly 20261026-0123abc (based on Raspberry Pi OS Lite)"`, all other lines identical to the mainline test's.
  - `--config-only --nightly 'x;y' OUT` and `--nightly 20261026-0123abc /nonexistent.deb` fail without writing OUT or creating `build/` (the DEB check comes before any cloning).
- [ ] **Step 2: Run `bats test/build-image.bats`.** Expected: new tests FAIL.
- [ ] **Step 3: Implement.** Argument parsing picks the mode; `write_config` takes the name and release label; nightly checks DEB exists before anything else (the caller keeps it outside `build/`, which the script wipes), then copies it into the stage. `check-image.sh` swaps `valid_version` for `valid_package_version`. Add `/upstream/` to `.gitignore`.
- [ ] **Step 4: Run the whole suite and shellcheck.** Expected: all pass.
- [ ] **Step 5: Commit** "Let the image build take a locally built nightly package".

### Task 3: Nightly manifest and release notes

**Files:**
- Modify: `scripts/make-manifest.sh`
- Create: `scripts/nightly-notes.sh`
- Test: `test/make-manifest.bats`, `test/nightly-notes.bats`

**Interfaces:**
- Consumes: `valid_nightly_stamp`, `valid_package_version`.
- Produces: `make-manifest.sh` accepts `--tag nightly-STAMP` (image must be `gbs-anywhere-nightly-STAMP-arm64.img.xz`), giving `name: "gbs-anywhere (nightly)"` and a description containing `STAMP` and `Untested nightly build`. `nightly-notes.sh --version PKGVER --tag TAG --commit SHA40 --deb-sha256 HEX --pi-gen-tag T --repo OWNER/NAME` prints Markdown.

- [ ] **Step 1: Write the failing tests.**
  - `make-manifest.bats`: with image `gbs-anywhere-nightly-20261026-0123abc-arm64.img` and tag `nightly-20261026-0123abc`: name, URL `…/releases/download/nightly-20261026-0123abc/gbs-anywhere-nightly-20261026-0123abc-arm64.img.xz`, icon under the same tag, description contains `20261026-0123abc` and `Untested nightly build`. A nightly tag with the mainline image name fails; `nightly-2026-x` fails.
  - `nightly-notes.bats`: output contains `**Nightly build: untested.**`, `https://github.com/Skamba/gbs-anywhere/commit/<SHA40>`, the package version, the SHA256, `gbs-anywhere_<version>-1_arm64.deb`, `packaging/build-release.sh`, the manifest link `…/releases/download/<tag>/gbs-anywhere-nightly.rpi-imager-manifest`, `Raspberry Pi is a trademark of Raspberry Pi Ltd`, `Not affiliated with Mahlkönig or Hemro`, `2.0.12`. Refused: a mainline version, a tag whose stamp doesn't match the version, a short commit, a non-hex SHA256.
- [ ] **Step 2: Run the two files.** Expected: new tests FAIL.
- [ ] **Step 3: Implement.** In `nightly-notes.sh`, the tag's stamp must equal the version's `YYYYMMDD` and `sha7` and the commit's first 7 characters.
- [ ] **Step 4: Run the whole suite and shellcheck.** Expected: all pass.
- [ ] **Step 5: Commit** "Add the nightly Imager manifest and release notes".

### Task 4: Nightly workflow and README

**Files:**
- Create: `.github/workflows/nightly.yml`
- Modify: `README.md`, `.github/workflows/build.yml` (shellcheck the new scripts in the `test` job)

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Write the workflow** (`name: Nightly image`; `schedule` `17 4 * * *` and `workflow_dispatch`; concurrency group `nightly`, no cancel):
  - `image` job on `ubuntu-24.04-arm`, 150 min: read `repos/Skamba/gbs-anywhere/commits/main` (`.sha`, `.commit.committer.date`) with `GH_TOKEN`; refuse a SHA not matching `^[0-9a-f]{40}$`; stop (output `skip=true`, later steps `if:`-guarded) when `gh release list --limit 1000 --json tagName` has a line matching `^nightly-[0-9]{8}-<sha7>$`; check out `Skamba/gbs-anywhere` at that SHA to `upstream/` (`persist-credentials: false`); `nightly-info.sh` → outputs; `docker run --rm -v "$PWD/upstream:/src" -w /src -e GBS_COMMIT -e DEB_VERSION rust:1-bookworm sh -c 'sh packaging/build-release.sh && cargo deb --no-build --locked --deb-version "$DEB_VERSION"'` with `DEB_VERSION=<version>-1`; `df -h /`; `build-image.sh --nightly`; `sudo check-image.sh`; manifest to `deploy/gbs-anywhere-nightly.rpi-imager-manifest`; `nightly-notes.sh` to `deploy/release-notes.md`; copy the icon and the `.deb` into `deploy/`; upload artifact `nightly-image`, 3 days.
  - `release` job (`needs: image`, `if: needs.image.outputs.skip != 'true'`, `contents: write`): download, `SHA256SUMS` over img.xz, manifest, icon, `.info`, `.deb`, `.sbom.xz` if present; `gh release create TAG --prerelease --latest=false --target "$GITHUB_SHA" --title "gbs-anywhere nightly STAMP image"`; then `gh release list --limit 1000 --json tagName,createdAt --jq 'sort_by(.createdAt) | reverse | .[].tagName' | scripts/old-nightlies.sh 7` and `gh release delete "$t" --yes --cleanup-tag` for each (needs a checkout for the script).
  - `actionlint` clean.
- [ ] **Step 2: README.** A "Nightly images" section after "Updating" (for testers: untested, pick the newest `nightly-…` pre-release on the releases page, open that release's `gbs-anywhere-nightly.rpi-imager-manifest`, the newest 7 are kept, flash a normal release to go back; with SSH, its `.deb` installs with `sudo apt install`), and a maintainers paragraph (built here from upstream `main` with upstream's `packaging/build-release.sh`, a nightly per new commit, the 60-day schedule rule and re-enabling it under **Actions → Nightly image → Enable workflow**, and a manual run). Licences section: nightly images contain a gbs-anywhere build made here from the linked upstream commit. Humanizer pass; wording greps.
- [ ] **Step 3: Run the whole suite, shellcheck and actionlint.** Expected: all clean.
- [ ] **Step 4: Commit** "Add the nightly image workflow".
- [ ] **Step 5: STOP and ask the owner** before pushing, and before the first manual nightly run (public pre-release).
