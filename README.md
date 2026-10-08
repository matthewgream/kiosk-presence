# kiosk + presence

A full-screen browser on the machine's own display, which switches the display off when nobody is
about and back on when someone moves.

| | |
|---|---|
| `kiosk.service` | cage (single-app Wayland compositor) running cog, showing `KIOSK_URL`, on tty1 as `kiosk` |
| `kiosk-presence` | reads the webcam, decides presence from motion, switches the output with `wlr-randr` |

## Install

```sh
make install          # packages, kiosk user, files, enable + restart both services
make status           # both services, last presence log lines
make diff             # repo copy against what is installed
make uninstall        # presence only; the kiosk stays
```

Config goes to `/etc/default/kiosk` (the URL) and `/etc/default/kiosk-presence` (the sensor). A
per-host `kiosk.<hostname>.cfg` / `kiosk-presence.<hostname>.cfg` is used instead when present.

## How it works

The camera streams raw YUYV at 320x240 (`v4l2-ctl`, no ffmpeg); about two frames a second are
reduced to a grid of 4x4-pixel blocks and compared with the previous one. Motion is more than
`threshold` % of blocks changing by more than `block-delta`, after removing any change common to
the whole picture, so auto-exposure and daylight drift do not count. No motion for `idle` seconds
and the output is disabled (`wlr-randr --output DP-1 --off`): the signal stops, the monitor goes
into its own standby, and the page stays loaded underneath. The first motion turns it back on.

It ignores the camera for `settle` seconds after each switch so the screen's own light change cannot
wake it, turns the screen on if the camera stops delivering frames, and turns it on when stopped.
Frames are analysed in memory and dropped -- nothing is stored or sent.

## Notes

- `output` in the config must name the connected output (`wlr-randr` lists them).
- The unit needs `ProtectHome=read-only`, not `yes`: `yes` hides `/run/user`, where cage's Wayland
  socket lives, and every switch fails with "failed to connect to display".
- Why not the monitor's own power control: a Lenovo TIO22Gen3 accepts DDC/CI standby but ignores the
  command to wake. Why not `wlopm`: cage 0.2 does not implement output power management, but it does
  implement output configuration, which `wlr-randr` uses.
- Tuning: `journalctl -u kiosk-presence` logs every switch and a per-minute motion summary.
  Measured at the desk: someone keeping still gives 2-11 % blips every few seconds.
