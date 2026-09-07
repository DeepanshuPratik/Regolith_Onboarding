# Sample distro themes

Two drop-in replacements for `data/branding/regolith/theme.css`, for checking
that the branding theme layer actually reaches what it claims to.

| File | Look |
|---|---|
| `theme-regolith-amber.css` | dark, warm amber, square corners |
| `theme-gnome-light.css` | light, Adwaita blue, pill buttons |

They are deliberately nothing like each other, so "did it pick up my theme?"
is answered from across the room rather than by comparing hex codes.

## Using one

```bash
cp data/branding/regolith/theme.css /tmp/theme.css.orig     # keep the original
cp docs/samples/theme-gnome-light.css data/branding/regolith/theme.css
meson compile -C build
./build/linux-onboarding
```

The branding directory is compiled into the binary, so a rebuild is required —
editing the file and relaunching changes nothing.

Put it back with `cp /tmp/theme.css.orig data/branding/regolith/theme.css`.

## What a theme can and cannot reach

`theme.css` is a **GTK** stylesheet, loaded at `STYLE_PROVIDER_PRIORITY_USER + 1`
so it wins over the app's own `data/css/*.css`. That covers the workflow
catalogue and the practice page.

It does **not** cover the welcome page or the featured slides. Those are
distro-authored HTML rendered by WebKit, styled by
`data/branding/regolith/slides/assets/style.css`. So click *Get Started* to see
your theme — the first page you land on is the one page a theme cannot touch.

Two companion knobs live outside this file, and both matter when the theme
changes brightness:

1. **`Background=` in `branding.conf`.** The colour painted before the deck has
   rendered its first frame (#33). It is a plain colour, not read from CSS, so
   a light theme with `Background=#232733` still opens on a dark rectangle.
   Pair `theme-gnome-light.css` with `Background=#fafafa`.
2. **`slides/assets/style.css`.** The HTML half's own palette. A light GTK
   theme against the shipped dark slides looks broken at the seam — which is
   the honest answer to one of #32's open questions, not a bug in your theme.

## Seeing the catalogue and practice pages

The app records that a desktop has been onboarded, keyed per desktop, and exits
silently on the next run:

```bash
./build/linux-onboarding --reset-state
```

Only the *first* matching workflow directory is read, so on a Regolith session
you see `workflows/regolith/` and nothing else. To look at another desktop's
set, say so explicitly:

```bash
XDG_CURRENT_DESKTOP=GNOME ./build/linux-onboarding
```

## The styling contract

Every class either sample sets is one the app puts on a widget. The full list,
from `data/css/app.css` and `data/css/flow.css`:

`.carousel` `.main-container` `.practice-page` `.title-1` `.heading`
`.text-secondary` `.notice` `.practice-heading` `.practice-command`
`.practice-description` `.media-container` `.pill-button`
`.pill-button.suggested-action` `.playButton` `.cancelButton`
`.practice-button` `.workflow-button` `.workflow-button .heading` `.add-tile`
`.add-tile-plus` `.focus-prompt` `.focus-prompt-text` `.command-block`

GTK3 CSS is not web CSS. Stick to the properties the app's own sheets use —
`background-color`, `background-image`, `color`, `border`, `border-radius`,
`box-shadow`, `font-family`, `font-size`, `font-weight`, `margin-*`,
`padding`, `opacity` — and use `alpha(#rrggbb, 0.2)` rather than `rgba()`.
Anything GTK cannot parse is a warning on stderr and a silently unstyled
widget.
