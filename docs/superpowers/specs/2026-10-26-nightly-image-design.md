# Nightly Pi image: design

Approved by the owner in chat on 2026-10-26. It extends
`2026-10-26-gbs-anywhere-pi-image-design.md`; everything there still holds
for mainline images.

## Why

Testers want to try gbs-anywhere's `main` on a Pi before a release. Upstream
publishes its nightly only as the Docker image `ghcr.io/skamba/gbs-anywhere:nightly`;
it attaches no nightly `.deb`, and a package built from `main` carries the
last release's version (`0.3.1-1`). The owner doesn't want to wait for an
upstream change.

## Decisions (owner's)

- This repo builds the nightly `.deb` itself from upstream `main`. This is an
  exception to "don't build the app from source here", for nightly only.
  Mainline images keep installing the pinned upstream release `.deb`.
- Nightlies are separate, dated pre-releases; the newest 7 are kept, older
  ones are deleted together with their tags.

## How it works

- **Trigger.** A daily schedule (04:17 UTC, after upstream's 02:23 nightly)
  and a manual run. Both read upstream `main`'s commit and stop without
  building when a nightly for that commit already exists. Upstream needs no
  change.
- **The package.** Check upstream out at that commit in the runner's
  workspace (never committed here) and run upstream's own
  `packaging/build-release.sh` unchanged, in `rust:1-bookworm` on the arm64
  runner, with `GBS_COMMIT` set to the commit as upstream does for
  non-release builds. Then, in the same container, `cargo deb --no-build
  --locked --deb-version <version>-1` re-packages the same binary with the
  nightly version.
- **Names** (designer's calls):
  - package version `X.Y.Z+gitYYYYMMDD.<sha7>`, where `X.Y.Z` is upstream
    `Cargo.toml`'s version at that commit and the date is the commit's (UTC).
    It sorts above release `X.Y.Z` and below the next release, so apt moves
    between nightly and mainline correctly. A `Cargo.toml` version that
    isn't plain `X.Y.Z` fails the build.
  - tag `nightly-YYYYMMDD-<sha7>`, image `gbs-anywhere-nightly-YYYYMMDD-<sha7>-arm64.img.xz`.
    The commit in the tag makes each nightly unique and lets the run see
    that a commit was already built.
  - Imager manifest `gbs-anywhere-nightly.rpi-imager-manifest`, OS name
    "gbs-anywhere (nightly)", a description that says it is untested.
- **Image.** The same pi-gen stage and the same `check-image.sh` as
  mainline, given the locally built `.deb`.
- **Release.** A pre-release, never marked latest, with the same kinds of
  assets as mainline plus the `.deb` itself. Notes say it is untested, link
  the exact upstream commit as the source (AGPL), give the package's SHA256,
  and say the package was built here with upstream's script.
- **Pruning.** After a nightly is published, nightly releases beyond the
  newest 7 (by publish time) are deleted with `--cleanup-tag`. Mainline
  releases are never touched.
- **README.** A short "Nightly images" section for testers (where to find
  them, untested, flash the release's own manifest, re-flash a mainline
  image to go back) and maintainer notes (how it's built; GitHub disables
  schedules in public repos after 60 days without repository activity, and
  how to re-enable).

## Non-goals

- A stable "latest nightly" link. `releases/latest` skips pre-releases;
  testers pick the newest nightly from the releases page.
- Nightly builds of upstream pre-release versions, or of any branch but `main`.
