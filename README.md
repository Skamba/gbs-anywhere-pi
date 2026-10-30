# gbs-anywhere for Raspberry Pi

A ready-to-flash SD card image for a Raspberry Pi with
[gbs-anywhere](https://github.com/Skamba/gbs-anywhere) already installed.
Put it on a card with Raspberry Pi Imager, start the Pi, and open the app on
your phone. You don't need a screen, a keyboard or the command line. The
image is based on Raspberry Pi OS Lite (64-bit) and adds gbs-anywhere and a
small setup Wi-Fi for when the Pi can't reach your network.

> Not affiliated with Mahlkönig or Hemro.

## What you need

- A Raspberry Pi 3, 4, 5, 400, 500 or Zero 2 W.
- A microSD card of 8 GB or more.
- A power supply for that Pi.
- A computer with [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
  **2.0.12 or newer**. Older versions can't set up this image.
- The name and password of your Wi-Fi. The Pi must be on the same network as
  the grinder, and the E64 WS only uses 2.4 GHz Wi-Fi. A network cable
  works instead of Wi-Fi.

## Flash the card

1. Download
   [gbs-anywhere.rpi-imager-manifest](https://github.com/Skamba/gbs-anywhere-pi/releases/latest/download/gbs-anywhere.rpi-imager-manifest)
   and open it. It opens in Raspberry Pi Imager, which now lists
   gbs-anywhere.

   Or, in Imager: **App Options → Content Repository → Edit → Use custom
   URL**, paste the link above, then **Apply & Restart**.

2. Choose your Raspberry Pi, then **gbs-anywhere**, then your SD card.

3. Go through the customisation steps. Don't skip them: they are the only
   way to give the Pi your Wi-Fi and a user.
   - **Hostname:** type `gbs-anywhere`. Imager may fill in a name you used
     before; replace it, or remember the name you keep.
   - **Localisation:** choose your capital city. This also sets the Wi-Fi
     country, without which the Pi's Wi-Fi stays off.
   - **User:** choose a username and password. The image has none of its
     own.
   - **Wi-Fi:** your network's name and password. This is required unless
     the Pi uses a network cable.
   - **Remote access (SSH):** leave it off unless you want to log in to the
     Pi from a computer.

4. Write the card, put it in the Pi and plug in the power.

Don't download the image and choose it with **Use custom** instead: Imager
skips the customisation steps for images chosen that way, so the Pi would
get no Wi-Fi and no user.

## First start

Give the Pi a few minutes the first time. Then, on a phone on the same
network, open:

**http://gbs-anywhere.local/**

If you typed another hostname in Imager, use `http://<that name>.local/`.
If the page doesn't open, find the Pi in your router's list of devices (it
shows up as `gbs-anywhere`) and open its IP address instead, for example
`http://192.168.1.20/`.

## If the Pi doesn't join your Wi-Fi

When the Pi can't connect (a typo in the password, or you changed your
Wi-Fi), it opens its own Wi-Fi network called `gbs-anywhere-` followed by
three digits. It has no password.

1. Join that network on your phone.
2. A page opens by itself; if it doesn't, go to `http://10.41.0.1/`.
3. Choose your home network and enter its password.

The Pi then joins your network and the setup network goes away. Go back to
your own Wi-Fi on the phone and open `http://gbs-anywhere.local/`. The app
isn't reachable while the setup network is up.

With a network cable plugged in, the Pi uses the cable and skips all of
this.

## Set up the E64 WS

On the grinder, go to **Settings → Connectivity → Machine To Machine →
Enable Xenia**, open **Configuration** and enter `gbs-anywhere.local` as the
host (or the hostname you chose, followed by `.local`).

If the grinder doesn't connect, enter the Pi's IP address instead (for
example `192.168.1.20`; your router's device list shows it next to the name
`gbs-anywhere`). Then tell your router to always give the Pi that address.
Routers call this "address reservation", "DHCP reservation" or "static
lease".

For the rest (recipes with Grind-by-Sync, pulling a shot), follow
[Set up the E64 WS](https://github.com/Skamba/gbs-anywhere#set-up-the-e64-ws)
in the gbs-anywhere README. For an E65 or E80 grinder, follow
[Set up an E65/E80 GbS](https://github.com/Skamba/gbs-anywhere#set-up-an-e65e80-gbs)
there, using `http://gbs-anywhere.local/` as the app's address.

## Updating

The app tells you under **Status** when a new version of gbs-anywhere is
out. A new image follows each release.

To update, flash the new image the same way. Flashing erases the card, so
you lose what you set up in the app, the shot history and the E65/E80
pairing. Imager remembers your Wi-Fi and user, so those come back.

If you turned on SSH, you can update the app without flashing and keep
everything. Log in to the Pi and run, with the new version number in place
of `<version>`:

```sh
wget https://github.com/Skamba/gbs-anywhere/releases/download/v<version>/gbs-anywhere_<version>-1_arm64.deb
sudo apt install ./gbs-anywhere_<version>-1_arm64.deb
```

## Nightly images

Nightly images let you try what's coming in the next gbs-anywhere release.
Each one is built from the newest commit on gbs-anywhere's `main` branch
and published without being tested on a Pi, so expect things to break now
and then.

They're on the [releases page](https://github.com/Skamba/gbs-anywhere-pi/releases)
as pre-releases named `nightly-<date>-<commit>`, for example
`nightly-20261026-0123abc`. Only the newest 7 are kept. To flash one, open
its release, download its `gbs-anywhere-nightly.rpi-imager-manifest` and
continue as in [Flash the card](#flash-the-card). Imager lists it as
**gbs-anywhere (nightly)**. To go back, flash a normal release.

If you turned on SSH, each nightly's package is attached to its release
too, and installs on a Pi running this image with
`sudo apt install ./gbs-anywhere_<version>-1_arm64.deb`.

## What the image changes

Compared with Raspberry Pi OS Lite (64-bit), this image only:

- sets the hostname to `gbs-anywhere`;
- installs gbs-anywhere from its release package, unchanged, except that the
  setup Wi-Fi starts it rather than the Pi at boot (the app and the setup
  page both use port 80);
- installs [comitup](https://github.com/davesteele/comitup) from Debian for
  the setup Wi-Fi, with its settings in `/etc/comitup.conf`;
- adds a small hook so a network cable works without the setup Wi-Fi
  (`/etc/NetworkManager/dispatcher.d/50-gbs-anywhere-wired`,
  `/usr/lib/gbs-anywhere-pi/gbs-anywhere-net` and a drop-in for
  `comitup.service`);
- turns IPv6 off (`ipv6.disable=1` in `cmdline.txt`). When an IPv6 address
  changes, avahi can rename the Pi to `gbs-anywhere-2.local` until it
  restarts, and the phone and the grinder find the app by that name. The
  app, the grinders and the setup Wi-Fi only use IPv4.

Like Raspberry Pi OS Lite, the image has no user password and SSH off until
you set them in Imager.

## For maintainers

### How releases work

Each day at 05:41 UTC the **Image** workflow looks up gbs-anywhere's
latest release. If this repository has no image of it yet, it builds the
image with [pi-gen](https://github.com/RPi-Distro/pi-gen), checks it, and
creates a pre-release `v<version>-<build>` (for example `v0.3.1-1`). A
manual run (**Actions → Image → Run workflow**, optionally with a version)
does the same at once. gbs-anywhere itself knows nothing of this
repository.

As with the nightly, GitHub disables the daily run after 60 days without
repository activity; turn it back on under **Actions → Image → Enable
workflow**. Test the pre-release on a real Pi by opening its own manifest
in Imager:

```
https://github.com/Skamba/gbs-anywhere-pi/releases/download/<tag>/gbs-anywhere.rpi-imager-manifest
```

Then edit the release, clear **Set as a pre-release** and set it as the
latest release. Only then does the link in [Flash the card](#flash-the-card)
serve it. A rebuild of the same version gets the next build number. Pushes
to `main` and pull requests build and check the image too, and keep it as a
workflow artifact for a week, but publish nothing.

### Nightly images

The **Nightly image** workflow runs every night at 04:17 UTC, and on a
manual run (**Actions → Nightly image → Run workflow**). If gbs-anywhere's
`main` has a commit that no nightly was built from yet, it checks
gbs-anywhere out at that commit and builds the package with gbs-anywhere's
own `packaging/build-release.sh`, unchanged, in `rust:1-bookworm`. It then
packages the same binary again as version
`<X.Y.Z>+git<YYYYMMDD>.<commit>`, with X.Y.Z from that commit's
`Cargo.toml` and the commit's date. That version sorts after release X.Y.Z
and before the next one. The image is built and checked like a release's,
and published as a pre-release that is never marked as latest. Nightlies
beyond the newest 7 are deleted together with their tags. gbs-anywhere's
source is never copied into this repository, and release images still
install the release's own package.

A change in this repository doesn't start a nightly by itself. To get one
now, run the workflow by hand with **rebuild** ticked: it builds
gbs-anywhere's current `main` again and replaces that commit's nightly.

In a public repository, GitHub disables scheduled workflows after 60 days
without repository activity. To turn the nightly back on, open
**Actions → Nightly image** and click **Enable workflow**.

### The app version

The version for pushes and pull requests is in
`GBS_ANYWHERE_VERSION`. The daily release check and a manual run with a
version override it; bump the file in a pull request when convenient.

### Moving to a new pi-gen tag

Put the new
`<date>-raspios-trixie-arm64` tag in `PI_GEN_TAG` and open a pull request.
Its build runs `scripts/check-image.sh` on the result. The Imager manifest
takes its device list from Raspberry Pi's official list at build time.

### Tests

Run `bats test/` and `shellcheck` on the scripts, as in the
workflow's `test` job. A full build needs Docker on 64-bit Arm Linux:
`scripts/build-image.sh 0.3.1 1`, then
`sudo scripts/check-image.sh deploy/gbs-anywhere-0.3.1-1-arm64.img.xz 0.3.1`.

## Licences

The image is a collection of separately licensed works: Debian and Raspberry
Pi packages, comitup and gbs-anywhere, each under its own licence. The
licence of every package is in `/usr/share/doc/<package>/copyright` on the
image. This includes Broadcom and Cypress firmware, whose licences allow
unmodified redistribution for use with that hardware.

gbs-anywhere is licensed under the
[AGPL-3.0-or-later](https://github.com/Skamba/gbs-anywhere/blob/main/LICENSE).
Each release's notes name the gbs-anywhere version in the image, link to its
upstream tag, and give the SHA256 of the unmodified package that was
installed.
A nightly image instead contains a package built in this repository with
gbs-anywhere's own packaging script, from the gbs-anywhere commit its notes
link to; the notes give that package's SHA256 too.

This repository's own files are under the [MIT licence](LICENSE).

The image is based on Raspberry Pi OS Lite and made for Raspberry Pi. It is
not made or endorsed by Raspberry Pi Ltd. Raspberry Pi is a trademark of
Raspberry Pi Ltd.

Not affiliated with Mahlkönig or Hemro.
