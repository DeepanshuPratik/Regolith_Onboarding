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
├── logo.png                          welcome.html, and the launcher icon
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

# Your branding's version. Optional, defaults to 0. See "Version gating" below.
Version=1.0

# The first page. Optional, defaults to welcome.html; set it empty to open
# on the slides instead.
Welcome=welcome.html

# Optional. Omit to show every .html in slides/ in filename order.
SlideOrder=01-tiling.html;02-workspaces.html;03-practice.html;

# Optional, default false.
AllowSlideScripts=false

# The window background. Optional; omit it to follow the user's GTK theme.
# Set it to whatever your theme.css paints .main-container — see "No white
# flash" below.
Background=#232733

# Optional. The branding version each slide first appeared in.
[Slides]
01-tiling.html=1.0
02-workspaces.html=1.0
03-practice.html=1.0

[Marketplace]
Name=Regolith Workflow Marketplace
Url=https://github.com/regolith-linux/onboarding-marketplace
```

`Name` is the only identity string left in this file, and it is here because it
is needed where no page is rendered: the catalogue, the startup log and
`--check-workflows`. Your logo and tagline used to have keys here too; they are
now markup inside `welcome.html`, because the welcome page renders in the same
WebKit deck as the slides. The `[Marketplace]` `Url` is what the `+` tile in
the catalogue hands to the system browser.

### No white flash: `Background` and the inline background

Nothing in this application parses your `theme.css`, so it cannot know what
colour your window is. `Background` is how you tell it, and it is worth setting:
it is the colour painted wherever your own content has not painted *yet*, which
in practice means the deck's first frame.

Two places need it, and both matter:

- **`Background=` in branding.conf** sets the WebView's base colour, which is
  otherwise opaque white. Match it to whatever `theme.css` paints
  `.main-container`. Omit it and the app follows the user's GTK theme, which is
  right for an unthemed build and wrong behind a dark sheet.
- **An inline background in each page's `<head>`**, because a stylesheet in a
  `<link>` is fetched over the `app://` scheme *after* the document starts
  painting. Until it arrives the document is white however the widget behind it
  is painted:

  ```html
  <style>html,body{background:#232733;color:#d8e0ee}</style>
  <link rel="stylesheet" href="assets/style.css">
  ```

The window also waits for your first page to finish loading before it maps
itself, so the first thing on screen is the deck rather than an empty frame. A
page that never loads does not hold the app hostage — there is a timeout, and
the window appears regardless.

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
| `.focus-prompt`, `.focus-prompt-text` | The "another window has the keyboard" prompt |

Note GTK CSS is not web CSS: there is no `max-width`, no `line-height`, no
flexbox. Unknown properties log a parse error and are ignored. This applies to
`theme.css` only — the welcome page and slides are real web pages and get real
CSS, which is why the screens you are most likely to want to design are HTML.

### Per-desktop colours

The same branding should not look identical on sway, GNOME and KDE, so the app
resolves an **accent colour** for the session it is running in. In order:

1. **`Accent=#rrggbb` in branding.conf.** Your choice, on every desktop. This is
   the opt-out, and it is the whole of it.
2. **The desktop's own accent**, where it will say: GNOME's
   `org.gnome.desktop.interface accent-color` (GNOME 47 and later), KDE's
   `AccentColor` in `kdeglobals`.
3. **A colour shipped per desktop** — Adwaita blue on GNOME, Breeze blue on KDE,
   and so on — so every session has an accent even when nothing can be read.

`ColorScheme=` decides dark mode the same way: `desktop` (the default, following
GNOME's `color-scheme` or KDE's named scheme), or `light`/`dark` to insist.

**Your `theme.css` still wins.** The palette is loaded beneath both the app's
stylesheet and yours, so it supplies defaults rather than overriding a design.
In GTK it defines three names, which the app's own sheet consumes and you may
too:

| Name | Is |
|---|---|
| `@onboarding_accent` | The resolved accent |
| `@onboarding_accent_fg` | A foreground that reads on it |
| `@onboarding_accent_dim` | The accent at 14% — hover and tint states |

**In the HTML deck** the same colour arrives as a custom property, from a
generated stylesheet served at `app:///palette.css`:

```html
<link rel="stylesheet" href="app:///palette.css">
<link rel="stylesheet" href="assets/style.css">
```

```css
:root {
  /* the desktop's, or your own if it could not be read */
  --accent: var(--desktop-accent, #6ab0f3);
}
```

Link it first, as above: your sheet comes second and therefore wins, which is
the same precedence as on the GTK side. It also sets `color-scheme`, which is
what makes a scrollbar or a form control inside a slide match the rest of the
app. Linking it is optional — a deck that ignores it is unaffected.

To see what any of this resolves to without opening a window:

```
$ ./build/linux-onboarding --check-workflows | head -3
desktop=KDE candidates=[kde, default] wayland=true wm=unknown
branding: Regolith
palette:  accent #3daee9, light
```

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
on your first slide, or on the catalogue if there are no slides to show — which
happens both when you ship none and on any run where version gating has emptied
the deck, so write that button to say "Get Started" rather than "Next slide".

This is a plain anchor, so it works with scripting off — that is the point of
doing it this way. An unknown action name is logged and ignored.

The welcome page is expected to carry its own button, and so is given the full
height with no Back/Next strip beneath it. Slides get that strip from the app
and usually need no action links at all.

### Version gating: showing new slides to existing users

The tool runs more than once. Showing an existing user the same three slides
every launch trains them to close the window, and showing them nothing means you
can never introduce anything. So the deck is filtered against what that user has
already seen.

Two keys drive it:

| Key | Meaning |
|---|---|
| `Version=` in `[Branding]` | The version of **your branding**, not of the application |
| `<slide>=` in `[Slides]` | The branding version that slide first appeared in |

`Version` is yours to move. Bump it when you add or rewrite a slide; leave it
alone when the application ships a bugfix release. Those are different events
with different owners, and tying the deck to the app's version would mean every
patch release re-showing the deck while a branding-only change showed nothing.

Both values are **dotted-numeric** — `1`, `1.0`, `3.10.2`. Nothing else is
accepted: no `v` prefix, no `1.0-rc1`, no `3.x`. A malformed value is rejected
with a warning rather than being ordered anyway, because the alternative is
`3.x` quietly sorting as `3` and a slide silently never appearing. The
comparison is numeric per segment, so `3.10` is above `3.9`; a missing segment
counts as zero, so `3.2` and `3.2.0` are the same version.

What each run shows:

| Situation | Deck |
|---|---|
| First run on this machine (no state file) | **Everything.** `Since` is ignored entirely |
| A user who last saw `1.0`, branding now `1.1` | Only slides whose version is above `1.0` |
| A user who is up to date | No slides at all — welcome, then the catalogue |

The first row is the important one. A brand-new user has no history to compute a
delta against, so they get the whole introduction; only upgraders get a delta.
This also means a slide with **no** `[Slides]` entry is treated as having always
existed: it is part of a first run, and never part of an upgrade.

The welcome page always shows, and the catalogue is always one click away. Only
the slides between them are gated.

#### Where the state lives, and when it is written

One file, `~/.config/linux-onboarding/state`, holding the last branding version
the user was shown **on each desktop**, one group per desktop:

```ini
[State:regolith]
LastSeenBrandingVersion=1.0

[State:gnome]
LastSeenBrandingVersion=1.1
```

Per desktop, not per machine, because a user who moves from Regolith to GNOME
has not seen your deck on GNOME — and what it introduces, the catalogue and the
practice loop, is different there. The group name is the normalised desktop id,
the same one that keys `workflows/` (see "Keyed by desktop environment"), so
`Regolith-Wayland` and `Regolith-X11` share one record.

A file written by a version before this carried a single `[State]` group with no
desktop in it. It records a version but not who saw it, so it is **not**
honoured: that user is treated as a first run once per desktop, and the old
group is dropped the next time anything is written. Showing a slide twice is an
annoyance; never showing it is the bug.

It is written when the user actually **reaches the last slide the deck owed
them**, not when the window opens. Recording at startup would mean someone who
opens the window and closes it on slide two is never shown slide three. When
there is no delta at all there is nothing to miss, so the version is recorded
straight away.

Someone who jumps from the welcome page to the catalogue is not recorded, and
sees the same slides next launch. Showing a slide twice is an annoyance; never
showing it is a bug.

#### Re-testing your own slides

```
./build/linux-onboarding --reset-state
```

Deletes that file, so the next run is a first run and shows everything again.
This is the flag you will use while writing slides — otherwise your own machine
is the one machine that has already seen them.

## The application id, and the desktop file named after it

`meson install` places two files besides the binary:

```
$datadir/applications/org.linux.Onboarding.desktop     the launcher entry
$datadir/icons/hicolor/512x512/apps/org.linux.Onboarding.png
```

`org.linux.Onboarding` is the application id. It is three things at once, and
they are the same string on purpose:

| Where | What it is |
|---|---|
| `APP_ID` in `src/Constants.vala` | the GApplication id, and what `main.vala` sets the program name to |
| the window's Wayland `app_id` | GTK3 sends `g_get_prgname()`, i.e. the program name, in `xdg_toplevel.set_app_id` |
| the desktop file's **basename** | how a compositor finds the app behind a window |

### Why the basename is load-bearing

On GNOME, taking the keyboard grab this app needs for practice asks the user
"the app *X* wants to inhibit shortcuts". Mutter remembers the answer — but it
records it against the desktop file it resolved from the window's `app_id`, by
looking for `<app_id>.desktop`. **If there is no such file, nothing is stored
and the dialog comes back on every single launch**, in the middle of a first-run
experience, with no explanation and nothing in the logs to point at.

That is a silent failure in both directions. Rename the desktop file and leave
`APP_ID` alone, or the reverse, and the build still succeeds, the app still
runs, `--check-workflows` still passes, and the only symptom is a security
prompt on every launch on a machine you may not be testing on.

So `meson.build` asserts it. `app_id` is declared once at the top of
`meson.build`, the installed desktop file is `data/$app_id.desktop`, and
configuration fails if `src/Constants.vala` does not declare the same string:

```
ERROR: app_id mismatch: meson.build says 'org.example.Welcome' but
src/Constants.vala does not declare APP_ID = "org.example.Welcome".
```

If you rebrand, change all three together:

1. `app_id` in `meson.build`
2. `APP_ID` in `src/Constants.vala`
3. rename `data/org.linux.Onboarding.desktop`, and its `Icon=` and
   `StartupWMClass=` keys, to match

Pick something specific. During the spike that produced this requirement, a
throwaway binary called `obs` inherited **OBS Studio's** stored permissions —
GNOME's matching is looser than you would like. A reverse-DNS id under a domain
you control is the safe shape; `onboarding` or `welcome` on their own are not.

### Name, comment and icon

Everything in the desktop file below the basename is yours. `Name`,
`GenericName` and `Comment` are deliberately generic (`Getting Started`) so they
read correctly under any distro; replace them with your own wording.

The icon is **not** a fixed asset of this repository — it is `logo.png` from
your `-Dbranding_dir`, installed under the application id. Rebranding the build
rebrands the launcher icon with it, and no distro ships another distro's logo by
accident. The contract that comes with that: **`logo.png` should be a square
PNG**, 512×512 in the shipped Regolith branding. A non-square one still
installs, it just looks wrong at launcher sizes. If your branding directory has
no `logo.png` at all, configuration warns and the launcher falls back to a
generic icon.

### On sway there is no app_id at all

Worth knowing when you go looking: on a Wayland session that supports it, the
window is a `zwlr_layer_shell_v1` surface, and layer surfaces carry a namespace
(`gtk-layer-shell`) rather than an `app_id` — `set_app_id` is never sent. The
desktop file matters on the paths that use a normal toplevel: GNOME, KDE, and
X11 (where the id becomes the `WM_CLASS`, which is what `StartupWMClass`
matches). GNOME is the one that makes it urgent.

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

Parsing is deliberately forgiving for *shipping* workflows — an unrecognised
field is logged and skipped rather than discarding the file, so a workflow
written against a newer schema still loads what this build understands. But a
`key_id`, which can arrive from a marketplace repository, is treated as
**untrusted input**: the app sanitises it before writing anything to the window
manager's config, and a `key_id` that contains a newline, a `}`, a `"` or a `#`
is rejected outright rather than written through. See "Security: the sanitiser"
below.

### Checking your workflows

```
./build/linux-onboarding --check-workflows
```

Resolves every step without opening a window and prints what each `key_id`
becomes — the bindsym the WM binding mode will install, the synthesized keypress
used as a fallback, and **what the desktop itself says the key is bound to**:

```
palette:  accent #2f6fb5, dark

Launching Applications  (bundled:regolith/01-launching.json)
    <> Enter             bindsym Mod4+Return         synth: ydotool key KEY_LEFTMETA+KEY_ENTER
                         bound here to: exec --no-startup-id x-terminal-emulator
    <><Shift> ?          bindsym Mod4+Shift+question synth: ...+KEY_LEFTSHIFT+KEY_SLASH
                         not bound on this desktop; the app will synthesize it
```

That third line is the one worth reading when you are authoring for a desktop
you do not use daily. None of its three answers is an error: *bound* means the
desktop performs the action itself, *not bound* means the app will synthesize
the keystroke, and *unknown* means this desktop has no readable binding table
(i3, or any session with no resolver) — normal, and not something you can fix in
a workflow file.

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

## Security: the sanitiser

Practice works on sway/i3 by writing a **binding mode** into the user's
`config.d` — a block that binds every workflow key to `nop` so the app can see a
press without the WM acting on it. Because those keys come from workflow JSON,
and a workflow can arrive from a marketplace repository as a hand-placed file,
a malicious `key_id` could otherwise terminate the `mode "..." {` block and
inject arbitrary sway config that the WM executes on reload.

Every `key_id` therefore passes through a sanitiser before it can become part of
the generated config. It rejects, with a reason printed to `--check-workflows`:

- a `key_id` containing a newline (terminates the block),
- one containing `}` (closes the block early),
- one containing `"` (breaks the mode-name string),
- one containing `#` (comments out the rest of the line),
- anything the key parser cannot turn into a valid bindsym spec — including a
  malformed `<...>` with no closing bracket, and an unrecognised modifier name,
  which used to be **silently dropped**, producing a key that simply never
  matched.

The app never downloads or runs anything; but the *result* of a user following
the marketplace's install instructions is still a JSON file that ends up in
sway's `config.d`, so the armouring lives in the app, not in the trust the user
places in a repository. This is why running `--check-workflows` after adding a
marketplace workflow matters: it is the offline place to learn which keys were
rejected and why.

## Which desktops support practice

The app is built around five **capability contracts**; a desktop implements any
subset of them, and what it cannot do is simply not offered, with an honest
explanation when the user would expect it. The five are:

| Contract | Answers | Interface is |
|---|---|---|
| `SessionProbe` | what session are we in | `claims_session()` + facts |
| `ShortcutObserver` | did the key get pressed | `install/start/arm/stop/uninstall` + `step_matched`/`aborted` |
| `BindingResolver` | what is this key bound to | `resolve(key_id, out command)` → BOUND/UNBOUND/UNKNOWN |
| `ActionDispatcher` | make the action happen | `dispatch(key_id, bound_command)` |
| `WindowPlacer` | keep the card out of the way | `shrink_for_practice()`/`restore()` |

Observation and dispatch are deliberately separate: a desktop can resolve and
dispatch a shortcut while being unable to observe a single press, and the
catalogue still works — it just drops the PLAY button.

The practical support table:

| Desktop | Practice | How |
|---|---|---|
| sway | Yes | Binding mode + IPC, no input grab |
| i3 | Yes | Binding mode + IPC; no resolver (keys are synthesized) |
| Any X11 session | Yes | Keyboard-only seat grab + GTK key events |
| GNOME on Wayland | Yes* | Keyboard-only seat grab → `zwp_keyboard_shortcuts_inhibit_v1` |
| KDE (KWin) on Wayland | Yes*† | Same keyboard-only grab; bindings from `kglobalshortcutsrc` |

\* GNOME ships a workflow set as of this branch — `workflows/gnome/`, three
workflows whose seven steps all resolve against GNOME's own GSettings. KDE is
**unauthored**: the platform implements observation, resolution and dispatch,
but no `workflows/kde/*.json` ship, so practice has nothing to teach there until
someone authors the set. The code path is complete the moment the JSON is
supplied.

Authoring for GNOME has one constraint worth knowing before you start, and it is
not obvious: **almost every GNOME default shortcut moves the keyboard somewhere
else.** Opening a terminal, switching windows, opening the app grid — each hands
focus to what it opened, and GNOME does not let an application take focus back
(see `docs/adr/0001-keyboard-only-grab.md`). The shipped set is ordered around
that: overlays that Escape dismisses come first, and the two steps that really
do move focus are last in their workflow, with descriptions that tell the user
to click the window to carry on. Order your steps the same way.

† KDE has **never been run on a Plasma machine**, and this table said it worked
for a while when no KDE code existed at all (#28). What exists now: `KdePlatform`
composes the same seat-grab observer and synthesis dispatcher GNOME uses, and
`KdeResolver` reads `kglobalshortcutsrc`, with its parsing covered by
`tests/test_kde_bindings.vala` and verified end-to-end against a synthetic
shortcut file. What has not happened is a run on Plasma. If you ship this on KDE,
`--check-workflows` is the first thing to run: it prints what each key is bound
to according to KWin's own file.

Where practice is unavailable the app says so plainly and presents the same
workflows as a reference card. Branding, slides and the catalogue work
everywhere.

## Adding a desktop

A new desktop is one directory plus two lines — no changes to shared code. That
is the whole contract, and this section is a walkthrough with a real example.

Say you are adding **Hyprland** and want it to observe and dispatch by its own
IPC while getting window placement from the generic Wayland placer.

Before writing an observer, check whether you need one. `src/platforms/seatgrab/`
holds the mechanism for desktops with no window-manager IPC — a keyboard-only
seat grab and the dispatcher that releases it to replay a keystroke — and X11,
GNOME and KDE all compose it rather than keeping a copy each. `src/platforms/kde/`
is the smallest example of what that leaves you writing: a `platform.vala` naming
the pieces, and a resolver for wherever that desktop keeps its bindings.

**1. Create `src/platforms/hyprland/`.** Put a `platform.vala` in it. The
platform declares which session it owns and returns the pieces of the five
contracts it implements; everything it does not return is left for the next
platform in the registry's list, or the registry's null implementation.

```vala
public class HyprlandPlatform : GLib.Object, Platform {
    public string id () { return "hyprland"; }

    public bool claims_session () {
        // how you tell this is Hyprland: an env var, a socket, a config path
        return Environment.get_variable ("HYPRLAND_INSTANCE_SIGNATURE") != null;
    }

    // Observation via a mode block + IPC, like sway's.
    public bool can_observe () { return true; }
    public ShortcutObserver? observer (Gtk.Widget owner) { return new HyprlandObserver (owner); }

    // Dispatch by running the resolved command through hyprctl.
    public ActionDispatcher? dispatcher (ShortcutObserver observer) { return new HyprlandDispatcher (); }
}
```

Every service factory is `Platform`-virtually and defaults to returning `null`,
so an implementation that offers only a subset — say observation without a
resolver — simply omits the others.

**2. Register it in `src/platforms/registry.vala` `all()`.** Most-specific
desktops go **above** the display-server layers and above any desktop that
names a session it does not actually drive (GNOME, which recognises itself by
name and so claims Regolith too). Hyprland goes right after sway:

```vala
private static Platform[] all () {
    return {
        new SwayPlatform (),
        new HyprlandPlatform (),
        new GnomePlatform (),
        new X11Platform (),
        new WaylandPlatform ()
    };
}
```

The order is the whole of the policy: the registry walks the list in order and,
for each of the five services, takes the first platform that claims the session
and offers a working implementation.

**3. Add one line to `src/platforms/meson.build`.**

```meson
subdir('hyprland')
```

That is it. `src/platforms/hyprland/platform.vala` calls this `linux_onboarding`
namespace and those service interfaces are compiled into the same build, so a
new file in the directory needs no other wiring — and a second `.vala` in the
directory (say a `resolver.vala`) is picked up by adding it to that directory's
own `meson.build`, alongside the sway/gnome/x11 ones.

The reason this stays compile-time rather than runtime (see
`docs/adr/0002-compile-time-registry.md`): a rebuild is cheap, a runtime plugin
contract would mean owning a public GObject ABI across Vala compiler versions,
and the set of desktops worth supporting changes about once a year. A
config-declared platform — a no-code `platform.conf` naming shell commands per
capability — is planned to layer on top without reshaping this, as one more
`Platform` in the list whose `claims_session()` reads a file.

## Marketplace repositories

The `+` tile in the catalogue opens your `branding.conf` `[Marketplace] Url` in
the user's real browser and quits the app. **The app never downloads, fetches
or runs anything** — the marketplace is a plain repository the user visits, and
installing from it is a manual act the user performs, having read the files.

Lay the repository out the same way as any other workflow source, so the
manual install command is a straight copy:

```
your-marketplace-repo/
└── workflows/
    ├── regolith/*.json
    └── gnome/*.json
```

### Installing a marketplace workflow by hand

The reference branding ships no install mechanism, so this is the command a
user actually runs to pull a workflow from a marketplace repository:

```bash
mkdir -p ~/.config/linux-onboarding/workflows/<desktop-id>
git clone <marketplace-url> /tmp/onboarding-marketplace
cp /tmp/onboarding-marketplace/workflows/<desktop-id>/*.json \
    ~/.config/linux-onboarding/workflows/<desktop-id>/
```

Where `<desktop-id>` is the workflow directory for their desktop (`regolith`,
`gnome`, `default`, …) — see "Keyed by desktop environment". A file in that
location shows up in the catalogue next to the built-in workflows on the next
launch, because workflow discovery reads `$XDG_CONFIG_HOME/...` at runtime.

After copying, run `--check-workflows`. It is the offline place to catch a bad
`key_id` — one that parses to an unmatchable key, or one the sanitiser rejected
— before it fails silently at runtime in the middle of a workflow. A single
rejected `key_id` in one marketplace workflow used to disable the binding mode
for *every* workflow; the sanitiser now refuses to write it at all (see
"Security: the sanitiser"), so a failure you care about surfaces in
`--check-workflows` rather than as a mysteriously missing shortcut.

Finally, do not hand users a script that pipes a marketplace file into sway's
config directly. The point of the install path above is that the file first sits
in the workflow directory, where the app's sanitiser gates it before it ever
reaches the window manager's `config.d`.
