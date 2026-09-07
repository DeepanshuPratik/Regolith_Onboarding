# Drop-in brandings

This directory holds **five** ready-to-fork brandings, one per desktop the app
ships default workflows for. Each is a complete drop-in: copy the directory,
edit `branding.conf` and `theme.css`, swap the logo and slides, point the build
at it.

| Branding | Style | Story it tells | Slides |
|---|---|---|---|
| `regolith/` | Dark, blue, square | Tiling, workspaces, practice — the reference. | 3 |
| `gnome/` | Light, Adwaita blue, pill buttons | Activities & overview, dynamic workspaces, extensions. | 4 |
| `regolith-wayland/` | Dark, blue, square | "Same Regolith, now driven by sway." | 4 |
| `sway/` | Almost-black, Nord frost, sharp | `$mod` is the only modifier that matters. | 4 |
| `x11/` | Charcoal, grey, square | X11 isn't a desktop — the WM you pick is. | 3 |

## Welcome pages

Each deck opens on a `welcome.html` that introduces the desktop in its own
voice — not generic onboarding copy. The carousel window is cropped from a
1280×800 Xephyr run.

| | |
|---|---|
| ![Regolith welcome — reference dark deck with the hexagonal R mark, blue Get Started pill, four-slide deck](docs/screenshots/regolith-welcome.png) | ![GNOME welcome — light surface with the Ubuntu-style circle, soft orange halo, Adwaita-blue pill, five-slide deck](docs/screenshots/gnome-welcome.png) |
| ![Regolith-on-Wayland welcome — same dark deck as Regolith, with "ON WAYLAND" subtitle in caps marking the successor](docs/screenshots/regolith-wayland-welcome.png) | ![sway welcome — terminal hero showing ~/.config/sway/config as the brand mark, frost-accent pill, five-slide deck](docs/screenshots/sway-welcome.png) |
| ![X11 welcome — fallback deck with a large white X glyph, "Welcome to X11" as the honest "this isn't a desktop" intro](docs/screenshots/x11-welcome.png) | |

The shipped `regolith/` is the reference — what the project itself is built
on. The others are *examples a maintainer can fork from* or *presets a maintainer
can ship* as part of a multi-branding binary.

## Trying one without changing your build

`meson setup build --reconfigure -DBranding_dir=data/branding/gnome` (or any
of the four below). Re-running it with the previous path puts you back. The
GResource manifest is regenerated at configure time, so a `meson compile -C
build` after the reconfigure is what actually embeds the new assets.

The five directories are siblings, not a hierarchy. A packaged build only
embeds one — the one `-DBranding_dir` pointed at. There is no default: a fresh
`meson setup build` with no `-DBranding_dir` fails at configure time and lists
these five, rather than quietly shipping Regolith's branding on a distro that
never chose it.

Want a sixth? Copy any of these five, edit its `branding.conf`, `logo.png`,
`theme.css` and `slides/`, and point `-DBranding_dir` at the copy — see
`docs/DISTRO-GUIDE.md`.

## What each one teaches

The deck is short on purpose: the *practice* screen does the heavy lifting.
The slides exist to name a concept (workspaces, `$mod`, Activities) and the
practice workflows bundled in each branding's own `workflows/` — `regolith/`
and `gnome/` ship one, currently — (or installed via the marketplace) deliver
the keystrokes.

- **`gnome/`** — Activities as the front door; workspaces that come and go;
  extensions when the desktop should grow. Built around the GNOME Wayland
  defaults; light surface, Adwaita blue accent, pill buttons, Ubuntu orange on
  the brand mark.
- **`regolith-wayland/`** — Regolith on sway instead of i3. Same Regolith,
  same shortcuts, same Rile control panel. The slide deck highlights the
  Wayland-specific wins: per-output scaling, swaybar, GTK4 panel.
- **`sway/`** — For a sway user who doesn't run Regolith. The deck assumes
  you read the config, and the welcome page shows a styled terminal so the
  brand reads as "your config, your desktop".
- **`x11/`** — Shown when the desktop in use isn't a known one. The story is
  honest: X11 is a protocol, your window manager is your desktop. Defaults to
  short and square because the session itself is unstyled.

## Theme tokens

Each slidesheet defines a small palette in `:root`. The ones that come from
the app (per-desktop accent, dark/light detection) are surfaced as
`--desktop-accent` via `app:///palette.css`; the ones that are branding-owned
are local. The structure is identical across all five so a maintainer can move
between them:

```css
:root {
  --bg: ...;          /* painted on the page background */
  --fg: ...;          /* body text */
  --muted: ...;       /* secondary text */
  --accent: var(--desktop-accent, #fallback);
  --key-bg: ...;      /* kbd chip background */
  --key-border: ...;  /* kbd chip border */
  --cta-bg: ...;      /* the Get Started pill */
  --cta-fg: ...;
}
```

The `--accent` default is what you see when the desktop's accent can't be
read (e.g. on x11 with no theme). The deck stylesheet is loaded *after*
`app:///palette.css` so a `var(--desktop-accent, …)` set here still wins for
values that are listed in the deck, and falls through to the palette for
anything else.

## The brand mark

Every branding ships a 512×512 `logo.png` for the launcher icon and a `<svg>`
mark inline in `welcome.html` so the page can recolour the logo from CSS
tokens (`--brand-orange` on GNOME, `--brand-paper`/`--brand-ink` on Regolith,
no SVG mark on sway — its brand *is* the config file). The launcher PNG and
the inline SVG are deliberately kept consistent: same shape, same colour
hierarchy.