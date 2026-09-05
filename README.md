# Linux Onboarding

A first-run onboarding tool for Linux distributions — the equivalent of the
"Get Started" experience Windows and macOS ship, built so any distro can put
its own name, look and content on it.

It opens with a welcome page, walks through a few slides the distro authors,
and then offers interactive workflows that teach keyboard shortcuts by
prompting for one at a time and waiting until the user actually presses it. The
real action happens when they do, so the shortcut is learned by using it rather
than by reading a table.

Originally written for [Regolith Linux](https://regolith-desktop.com), which
remains the reference branding shipped in this repository.

## Building

```bash
meson setup build
meson compile -C build
./build/linux-onboarding
```

Build dependencies: `valac`, `meson`, `gtk+-3.0`, `libhandy-1`, `json-glib-1.0`,
`gee-0.8`, `gtk-layer-shell`, `webkit2gtk-4.1`.

On Debian and Ubuntu, `libwebkit2gtk-4.1-dev` comes from **universe**. There is
no `4.0` package on Ubuntu 24.04 and later; it must be `4.1`.

Validate a set of workflows without launching the UI:

```bash
./build/linux-onboarding --check-workflows
```

## For distro maintainers

Everything the user sees is replaceable. Point the build at your own branding
directory:

```bash
meson setup build -Dbranding_dir=/path/to/my-distro-branding
```

That directory holds your `branding.conf`, `theme.css`, logo, HTML slides and
default workflows, and all of it is compiled into the binary — a shipped build
carries its own identity and cannot lose it. Workflows are additionally
discovered from disk at runtime, so they can be extended after release.

**→ [docs/DISTRO-GUIDE.md](docs/DISTRO-GUIDE.md)** covers the directory layout,
`branding.conf`, the theming contract, the workflow JSON schema, how workflows
are keyed by desktop environment, and how to lay out a marketplace repository.

## Which desktops are supported

| Desktop | Interactive practice |
|---|---|
| sway, i3 | Yes — via a WM binding mode and IPC, with no input grab |
| Any X11 session | Yes — via a seat grab |
| GNOME, KDE on Wayland | Not yet — the compositor consumes its shortcuts before any client sees them |

Where practice is unavailable the app says so plainly and presents the same
workflows as a reference card. Branding, slides and the catalogue work
everywhere.

## How it fits together

```
src/
├── platform/     desktop and session detection from XDG_CURRENT_DESKTOP
├── branding/     the compiled-in distro identity
├── slides/       WebKit-rendered featured slides
├── workflows/    workflow model, tolerant parser, layered discovery
├── capture/      how a keypress is noticed, per desktop
├── flow/         the catalogue and the step-by-step practice page
└── intro/        the welcome page
```

`capture/` is the part worth knowing about. Detecting that a shortcut was
pressed differs enough between desktops that it cannot be one code path, so
`CaptureBackend` defines the contract — `available` / `start` / `arm` /
`dispatch` / `stop`, plus `step_matched` and `aborted` signals — and each
desktop family implements it:

- **`WmModeBackend`** (sway, i3) writes a binding mode into the WM's `config.d`
  and subscribes to binding events over IPC. Keys are bound to `nop` inside the
  mode, so a press is observed without the WM acting on it, and the app then
  performs the real action itself by resolving what the key is normally bound
  to. No input grab, so the rest of the desktop stays usable.
- **`SeatGrabBackend`** grabs the seat and reads GTK key events. Correct on X11.
- **`UnsupportedBackend`** reports honestly rather than offering a control that
  would silently do nothing.

## Adding a desktop

Implement `CaptureBackend` in `src/capture/` and return it from
`CaptureBackends.choose()`. For GNOME the bindings are readable from the
`org.gnome.desktop.wm.keybindings` and
`org.gnome.settings-daemon.plugins.media-keys` GSettings schemas; the open
problem is observing the presses.

## Screenshots

<img alt="Sample1" height="200" src="data/images/sample1.jpeg" />
<img alt="Sample3" height="200" src="data/images/sample3.jpeg" />
<img alt="Sample4" height="200" src="data/images/sample4.jpeg" />
<img alt="Light theme" height="200" src="data/images/regolith%20light%20theme.jpeg" />

## Licence

Apache 2.0. See [LICENSE](LICENSE).
