# Shipping this on your distro

This is a first-run onboarding tool: a welcome page, a few featured slides, and
a set of interactive workflows that teach keyboard shortcuts by making the user
actually press them. Everything a distro shows is yours to replace.

The split to understand before anything else:

| | Where it comes from | Why |
|---|---|---|
| Branding, theme, logo, slides | **Compiled into your build** | A shipped build carries its own identity. It cannot go missing, be half-installed, or change underneath the user. |
| Workflows | **Found on disk at runtime** | These are meant to be extended after release, by you, by an admin, or by the user. |

## Building with your branding

Copy `data/branding/regolith/` as a starting point, edit it, and point the build
at it:

```bash
meson setup build -Dbranding_dir=/path/to/my-distro-branding
meson compile -C build
./build/linux-onboarding
```

Everything in that directory is compiled in. The resource manifest is generated
at configure time, so you never hand-maintain a file list — add a slide and
rebuild.

### Directory layout

```
my-distro-branding/
├── branding.conf                     required
├── welcome.html                      your first page
├── logo.png                          referenced by welcome.html
├── theme.css                         optional
├── slides/                           optional
│   ├── 01-tiling.html
│   ├── 02-workspaces.html
│   └── assets/
│       ├── style.css
│       └── screenshot.png
└── workflows/                        optional, these become your defaults
    └── <desktop-id>/
        ├── 01-launching.json
        └── images/
            └── launch.png
```

### branding.conf

```ini
[Branding]
Name=Regolith
Theme=theme.css

# The first page. Optional, defaults to welcome.html; set it empty to open
# on the slides instead.
Welcome=welcome.html

# Optional. Omit to show every .html in slides/ in filename order.
SlideOrder=01-tiling.html;02-workspaces.html;03-practice.html;

# Optional, default false.
AllowSlideScripts=false

[Marketplace]
Name=Regolith Workflow Marketplace
Url=https://github.com/regolith-linux/onboarding-marketplace
```

`Name` is the only identity string left in this file, and it is here because it
is needed where no page is rendered: the catalogue, the startup log and
`--check-workflows`. Your logo and tagline are markup in `welcome.html`.

### theme.css

Plain GTK3 CSS, loaded *after* the application's own stylesheet so your rules
win. The styling contract — the class names worth overriding — is:

| Class | Applies to |
|---|---|
| `.main-container`, `.practice-page` | The window's content panels |
| `.title-1` | Page titles |
| `.heading` | Step headings and tile captions |
| `.text-secondary` | Secondary copy under a heading |
| `.notice` | Warnings and explanatory notes |
| `.pill-button.suggested-action` | Primary buttons |
| `.playButton`, `.cancelButton` | Practice controls |
| `.workflow-button`, `.add-tile` | Catalogue tiles |
| `.command-block` | The marketplace command box |

Note GTK CSS is not web CSS: there is no `max-width`, no `line-height`, no
flexbox. Unknown properties log a parse error and are ignored. This applies to
`theme.css` only — the welcome page and slides are real web pages and get real
CSS, which is why the screens you are most likely to want to design are HTML.

### The HTML deck

The welcome page and the slides after it are ordinary HTML files rendered by
WebKitGTK, in one deck sharing one web process. Relative references work — a
slide at `slides/01-tiling.html` can use `<img src="assets/x.png">`, and
`welcome.html` at the top of your directory can use `<img src="logo.png">` —
because the bundle is served over an internal `app://` scheme.

Constraints, because these are content rather than code:

- **JavaScript is disabled** unless you set `AllowSlideScripts=true`. You do
  not need it to navigate; see the action links below.
- **Navigation stays inside the bundle.** An `http(s)` link is handed to the
  user's real browser instead of loading in the window.
- **Everything must be bundled.** There is no network fetch, so remote fonts,
  CDN stylesheets and hotlinked images will not load. Inline them or ship them
  in `assets/`.
- Pages are sized for roughly 780×380 logical pixels. Design for that and let
  the content breathe rather than filling every pixel.

#### Talking back to the app: `app://action/`

A link to the reserved `action` host is intercepted rather than loaded, and
moves the deck instead:

```html
<a href="app://action/next">Get Started</a>
```

| Link | Does |
|---|---|
| `app://action/next` | The page after this one |
| `app://action/back` | The page before this one |
| `app://action/catalogue` | Straight to the workflow catalogue |

`next` and `back` are relative to the page the link is on, so the same markup
works wherever you move a page in the deck. `next` from the welcome page lands
on your first slide, or on the catalogue if you ship no slides.

This is a plain anchor, so it works with scripting off — that is the point of
doing it this way. An unknown action name is logged and ignored.

The welcome page is expected to carry its own button, and so is given the full
height with no Back/Next strip beneath it. Slides get that strip from the app
and usually need no action links at all.

## Workflows

A workflow is a titled sequence of keybinding steps. The user is prompted for
one shortcut at a time; when they press it, the action it is really bound to
happens, so they see the effect.

### Where they are found

All four layers are read and the results combined, so a user-installed workflow
appears next to your built-in ones:

```
resource:///org/linux/Onboarding/branding/workflows/   your build
$XDG_DATA_DIRS/linux-onboarding/workflows/             distro packages
$XDG_CONFIG_DIRS/linux-onboarding/workflows/           sysadmin (/etc/xdg)
$XDG_CONFIG_HOME/linux-onboarding/workflows/           the user (~/.config)
```

### Keyed by desktop environment

Each of those directories holds one subdirectory per desktop id:

```
workflows/regolith/*.json
workflows/gnome/*.json
workflows/default/*.json
```

The id comes from `XDG_CURRENT_DESKTOP`, which is a colon-separated list. Each
token is lowercased and stripped of a trailing `-wayland` / `-x11`, then tried
in order, then `default`:

```
Regolith-Wayland:GNOME:sway  ->  regolith, gnome, sway, default
ubuntu:GNOME                 ->  ubuntu, gnome, default
KDE                          ->  kde, default
```

Within a layer only the first match is read, so shipping both `regolith/` and
`default/` gives Regolith users the specific set rather than both.

Because the session suffix is stripped, `Regolith-Wayland` and `Regolith-X11`
share one directory.

### File format

```json
{
  "version": 1,
  "desktop": "regolith",
  "workflows": [
    {
      "name": "Launching Applications",
      "description": "Open the apps you use most without reaching for the mouse.",
      "image": "images/launch.png",
      "steps": [
        {
          "key_id": "<> Enter",
          "heading": "Launch a Terminal",
          "description": "Opens your terminal.",
          "image": "images/terminal.gif"
        }
      ]
    }
  ]
}
```

`image` paths resolve relative to the directory holding the JSON file, so a
workflow carries its own artwork.

`key_id` uses the remontoire notation Regolith already uses in its config
comments: modifiers in angle brackets, then a space, then the key. `<>` on its
own is the Super key.

```
<> Enter            Super+Enter
<><Shift> Enter     Super+Shift+Enter
<><Ctrl> r          Super+Ctrl+r
<> ←                Super+Left
<> 2                Super+2
```

Parsing is deliberately forgiving. An unrecognised field is logged and skipped
rather than discarding the file, so a workflow written against a newer schema
still loads what this build understands. Older key names (`workspaces`,
`workflow_name`, `workflow_description`, `key_bindings_sequence`, and
`function` for a step's description) are still accepted.

### Checking your workflows

```
./build/linux-onboarding --check-workflows
```

Resolves every step without opening a window and prints what each `key_id`
becomes — the bindsym the WM binding mode will install, and the synthesized
keypress used as a fallback:

```
Launching Applications  (bundled:regolith/01-launching.json)
    <> Enter             bindsym Mod4+Return         synth: ydotool key KEY_LEFTMETA+KEY_ENTER
    <><Shift> ?          bindsym Mod4+Shift+question synth: ...+KEY_LEFTSHIFT+KEY_SLASH
```

It exits non-zero if anything is wrong, so it can gate your packaging. Worth
running whenever you edit a workflow: a bad `key_id` fails quietly at runtime —
the window manager rejects the whole mode block, or the step simply never
matches — and neither is obvious without reading logs mid-workflow.

Note that `key_id` uses remontoire names, not X11 keysym names; the app
translates between them (`?` becomes `question`, `Space` becomes `space`). If
you write a key the translation does not cover, `--check-workflows` is where
you will find out.

### Choosing steps

Two things worth keeping in mind:

- **Do not use destructive bindings.** Logout, Reboot, Power Down and Exit App
  all work, and all of them are a poor thing to ask someone to press during a
  tutorial. The shipped Regolith workflows deliberately omit them.
- **`Escape` is reserved.** It is how the user backs out of a workflow, so a
  step bound to it cannot be captured.

## Which desktops support practice

| Desktop | Capture | How |
|---|---|---|
| sway, i3 | Yes | A binding mode is installed in `config.d` and binding events are read over IPC. No input grab, so the rest of the desktop keeps working. |
| Any X11 session | Yes | Seat grab plus GTK key events. |
| GNOME, KDE on Wayland | No | The compositor consumes its own shortcuts before any client sees them, and exposes no binding-event stream. |

Where practice is unavailable the app says so and presents the workflows as a
reference card. Branding, slides and the catalogue all still work.

Adding a desktop means implementing `CaptureBackend` in `src/capture/` and
returning it from `CaptureBackends.choose()`. For GNOME the bindings themselves
are readable from the `org.gnome.desktop.wm.keybindings` and
`org.gnome.settings-daemon.plugins.media-keys` GSettings schemas; the missing
half is a way to observe the presses.

## Marketplace repositories

The `+` tile in the catalogue points at the URL from your `branding.conf` and
shows the user the commands to install from it. **The app never downloads or
runs anything** — it displays commands and opens the URL in the system browser,
and the user runs them themselves having read them.

For the displayed `cp` command to be correct, lay the repository out the same
way as any other workflow source:

```
your-marketplace-repo/
└── workflows/
    ├── regolith/*.json
    └── gnome/*.json
```
