# Shrink-to-corner window positioning across desktops

## Requirement

The onboarding app currently places itself using `gtk-layer-shell` (an
`OVERLAY` layer surface with `EXCLUSIVE` keyboard interactivity) on Wayland,
and `Gdk.Window.move_resize` on X11. We want a new capability: while the user
practices a keyboard shortcut, shrink the app down to a small tile in a
screen corner, then restore it to its original size and position when the
practice step ends. This doc surveys what mechanisms actually exist for that,
per desktop environment, so we don't build against an assumption that doesn't
hold on a given compositor.

This is a research note, not a design decision. Where sources conflict or
where I could not get a primary source to load (some GitLab issue pages are
JS-rendered SPAs that our fetch tooling only sees the shell of), that is
called out explicitly rather than papered over.

---

## 1. Does Mutter/KWin implement `zwlr_layer_shell_v1`? What happens if you call `gtk_layer_init_for_window` anyway? How do you detect support first?

**Mutter (GNOME Wayland): not implemented.** The gtk-layer-shell README's own
compatibility list states plainly that "Gnome-on-Wayland" is a compositor
where Layer Shell "is not supported"
([README.md, wmww/gtk-layer-shell](https://github.com/wmww/gtk-layer-shell)).
There is a long-standing Mutter work item, "implement layer_shell protocol"
(GNOME/mutter#973,
<https://gitlab.gnome.org/GNOME/mutter/-/issues/973>), proposing it so
alternative shells could run as separate layer-shell clients — but I was
**not able to verify its current open/closed state or read the comment
thread**: the GitLab issue page is a JS-rendered single-page app and our
fetch tooling only retrieves the static shell (title + description), not the
discussion. Multiple secondary sources (GitHub discussions, package trackers)
corroborate the current community understanding that "pretty much all major
Wayland compositors besides GNOME" implement `wlr-layer-shell` (wlroots
compositors, Smithay/COSMIC, KWin) — treat this as widely-reported but not
independently confirmed against a Mutter commit or changelog.

**KWin (KDE Plasma, including Plasma 6): implemented.** The same
gtk-layer-shell README entry lists "KDE Plasma on wayland" as a compositor
where Layer Shell "is supported"
([README.md, wmww/gtk-layer-shell](https://github.com/wmww/gtk-layer-shell)).
This is also corroborated by KDE's own `layer-shell-qt` component
(<https://github.com/KDE/layer-shell-qt>), a Qt wrapper specifically built
so KDE/Qt apps can use `wlr-layer-shell`. Community reports (Noctalia's
compositor-notes page, <https://docs.noctalia.dev/noctalia/compositor-settings/kde/>)
say plainly "Layer-shell bars and panels work" under KWin, alongside a
caveat that "several features depend on wlroots-style protocols that stock
KWin does not expose." **I could not find a primary KDE source (KWin source
tree or changelog) confirming or denying an app_id allowlist restricting
which clients may use layer-shell**, despite specifically searching
invent.kde.org for it — the searches surfaced only tangential material
(security-context-based permission lookups in an unrelated MR, KWin Rules
wiki page). I could also not confirm from a primary source whether KWin's
layer-shell implementation supports the `EXCLUSIVE` keyboard-interactivity
mode our app currently requests (as opposed to `ON_DEMAND`/`NONE`) — treat
this as an open risk to validate empirically on a Plasma 6 Wayland session
before relying on it, rather than an assumption either way.

**What happens if `gtk_layer_init_for_window` is called where layer-shell
isn't supported:** per the gtk-layer-shell header
(`include/gtk-layer-shell.h`,
<https://github.com/wmww/gtk-layer-shell/blob/master/include/gtk-layer-shell.h>),
the doc comment for `gtk_layer_init_for_window` is:

> `gtk_layer_init_for_window: @window: A #GtkWindow to be turned into a layer`
> `surface once it is mapped. this must be called before the @window is`
> `realized.`

The header text does not itself document a crash/abort path. Independent
reports (multiple GitHub issues surfaced by search, e.g. a "GTK Layer Shell
not supported on Gnome 42 (but works)" issue on an unrelated project) say the
library prints a warning at runtime — "It appears your Wayland compositor
does not support the Layer Shell protocol" / "GTK Layer Shell is not
supported on this wayland compositor" — when the protocol isn't advertised.
I was not able to load gtk-layer-shell's actual `.c` source to confirm
whether that warning is a non-fatal `g_warning` (degrade to a normal
`xdg_toplevel` window) or a fatal `g_error`/`abort()`; this should be
verified directly against `gtk-layer-shell.c` (or empirically, by running
the app under GNOME Wayland) before depending on either behavior.

**The correct detection function, and when it shipped:** `gtk_layer_is_supported()`.
Its doc comment in the public header is:

> `gtk_layer_is_supported: May block for a Wayland roundtrip the first time`
> `it's called. Returns: %TRUE if the platform is Wayland and Wayland`
> `compositor supports the zwlr_layer_shell_v1 protocol. Since: 0.5`

(<https://github.com/wmww/gtk-layer-shell/blob/master/include/gtk-layer-shell.h>).
So it was introduced in **gtk-layer-shell 0.5**, and the correct pattern is
to call `gtk_layer_is_supported()` before ever calling
`gtk_layer_init_for_window()`, and fall back to plain X11/`xdg_toplevel`
GTK window management when it returns `FALSE`. Note the "may block for a
roundtrip" warning — call it once, cache the result, don't call it on a hot
path.

---

## 2. On GNOME/Mutter Wayland, what positioning can a plain `xdg_toplevel` client get?

**Confirmed: no.** A client cannot set its own absolute on-screen position.
Per the xdg-shell protocol spec itself (`xdg_toplevel` interface,
<https://wayland.app/protocols/xdg-shell>), the toplevel's state-changing
requests are `move` (an *interactive, user-driven* move — the compositor
handles the drag, not a client-supplied coordinate), `set_maximized`,
`set_fullscreen`, and `set_minimized`. None of these accept, or exist to
convey, an arbitrary (x, y). Canonical's own Mir documentation on this exact
subject (<https://canonical.com/mir/docs/stable/explanation/window-positions-under-wayland/>)
states it as deliberate protocol philosophy: "throughout the design of
Wayland the approach has been for the client to make requests and the
server to make the final decisions," citing both consistency ("only the
server can provide consistent window behaviors across multiple applications
and toolkits") and security ("there are even security concerns about placing
windows to intercept input such as passwords") as the reasons.

The alternatives you listed are correctly ruled out:

- **`xdg_positioner`** — per spec, this exists to position `xdg_popup`
  surfaces relative to a parent surface; it dismisses on focus loss and is
  not a persistent-standalone-window mechanism
  (<https://wayland.app/protocols/xdg-shell>).
- **`set_fullscreen`/`set_maximized`** — these only ask the compositor for
  its own fullscreen/maximized geometry; the client doesn't choose the
  rectangle.
- **Plain GTK size requests** (`gtk_window_set_default_size`, etc.) — only
  affect the window's own dimensions, never its screen position.

So the honest answer for GNOME/Mutter Wayland is: **there is currently no
client-side mechanism to set absolute position at all**, for either the
"shrink" or "restore" half of this feature, using a plain `xdg_toplevel`.

---

## 3. Is there anything new (portal or protocol) for client-requested placement on GNOME/KDE as of 2026?

**Short answer: nothing that solves this problem exists or is deployed yet,
but there is one relevant, very recent development worth tracking.**

- **`xdg_activation_v1`** is about requesting focus/activation for a
  surface (handing another client a token so it can raise/focus a window),
  not placement — "it's up to the compositor to display this information as
  desired, for example by placing the surface above the rest"
  (per protocol docs surfaced via search,
  <https://wayland.app/protocols/xdg-activation-v1>). It doesn't give
  coordinates.
- **`ext-session-lock-v1`** is the screen-lock protocol (compositor stops
  rendering/inputting to normal clients and blanks outputs while a lock
  surface is shown) — unrelated to placement
  (<https://wayland.app/protocols/ext-session-lock-v1>).
- **`xdg-session-management-v1`** (merged into wayland-protocols 1.48,
  reported by Phoronix, <https://www.phoronix.com/news/Wayland-Protocols-1.48>)
  is new, but it is explicitly a **session-restore** mechanism, not a live
  positioning API. Its own spec text (fetched via
  <https://isaacfreund.com/docs/wayland/xdg-session-management-v1/>) says
  it lets clients "restore toplevel state from previous executions," that
  restoration must be requested "before the toplevel is mapped," and that
  "clients must account for missing sessions and partial session
  restoration" — i.e. the compositor may or may not honor it, and it only
  fires once at startup, not on demand mid-session. **Not usable** for a
  runtime shrink/restore during active use.
- **`xx-zones` / `ext-zones`** — this is the one genuinely new and relevant
  thing. Per Phoronix (article dated **2026-02-10**,
  <https://www.phoronix.com/news/Wayland-Experimental-Zones>), an
  experimental "zones" protocol was merged into wayland-protocols after
  "2+ years, 620+ comments" of discussion (referenced also by the Hackaday
  retrospective on Wayland positioning debates,
  <https://hackaday.com/2025/11/11/waylands-never-ending-opposition-to-multi-window-positioning/>,
  which frames it as the successor to an earlier rejected MR#247). What it
  actually offers, per the protocol text Phoronix quotes: "The client can
  only know window positions relative to the zone the compositor has
  assigned to it, and a zone can be a defined rectangle with fixed
  dimensions, or an infinite space without any limits." That is a
  **compositor-defined, relative coordinate system for multi-window apps to
  arrange their own windows against each other** — it is not a "put my
  window at screen pixel (X, Y)" API, and as of the article's publish date
  I found **no confirmation that Mutter or KWin actually implement it yet**
  (it was merged into the *protocol* spec, not shipped in any compositor per
  the sources I could reach). Also worth noting: KDE has its own prior
  proprietary `kwin-zones` experiment (<https://github.com/KDE/kwin-zones>,
  described as "Wayland ext-zones for KWin"), suggesting KDE was already
  prototyping in this space before the generic protocol merged — but I
  could not confirm whether that KDE prototype and the merged wayland-protocols
  `xx-zones` are the same effort or converged.

**Honest bottom line for Q3: no shipped, real mechanism exists today (Sept
2026) for a GNOME- or KDE-Wayland client to say "put me at this exact
screen position."** The closest thing is the brand-new, not-yet-implemented
`xx-zones` protocol, and even that is scoped to relative arrangement within
a compositor-granted zone, not free-form absolute placement — do not build
a near-term plan around it.

---

## 4. sway/i3 IPC-based positioning: correct commands, and correct sequencing

**Yes** — on sway (and i3 under X11), the WM's own IPC can do exactly what
layer-shell does for us, independent of the layer-shell protocol, because
sway/i3 let you float, resize, and move any matched window at any time, not
just at creation.

### sway (Wayland, `app_id` criterion)

Per `sway(5)` (verified against the upstream `.scd` source,
<https://github.com/swaywm/sway/blob/master/sway/sway.5.scd>, and the Arch
mirror <https://man.archlinux.org/man/sway.5.en>):

```
# one-off, issued at the moment the app wants to shrink:
swaymsg '[app_id="my-onboarding-app"] floating enable'
swaymsg '[app_id="my-onboarding-app"] resize set 240 px 160 px'
swaymsg '[app_id="my-onboarding-app"] move position 20 px 20 px'

# to restore:
swaymsg '[app_id="my-onboarding-app"] resize set <orig_w> px <orig_h> px'
swaymsg '[app_id="my-onboarding-app"] move position <orig_x> px <orig_y> px'
# (or, if it started centered/tiled: `move position center`, or `floating disable`)
```

`resize set` syntax: `resize set [width] <width> [px|ppt] [height] <height>
[px|ppt]`, described as "Sets the width and height of the container to
_width_ and _height_." `move position` syntax: `move [absolute] position
<pos_x> [px|ppt] <pos_y> [px|ppt]`, "Moves the focused container to the
specified position," with `move position center` and `move position
cursor|mouse|pointer` variants also available. `floating enable|disable|toggle`:
"Make focused window floating, non-floating, or the opposite of what it is
now." (All quotes from the man page fetch above.)

### i3 (X11, `class`/`instance`, **no `app_id`**)

i3's criteria set, per the official user guide
(<https://i3wm.org/docs/userguide.html>), is `class`, `instance`, `title`,
`window_role`, `window_type`, `machine`, `id`, `urgent`, `workspace`,
`con_mark`, `con_id`, `floating`/`floating_from`, `tiling`/`tiling_from`,
and `all` — **there is no `app_id` criterion**, because i3 is X11-only and
identifies clients via `WM_CLASS` (`class` = second/general part,
`instance` = first/specific part), not the Wayland `app_id` concept.
Equivalent one-off sequence:

```
i3-msg '[class="MyOnboardingApp"] floating enable'
i3-msg '[class="MyOnboardingApp"] resize set 240 160'
i3-msg '[class="MyOnboardingApp"] move position 20 20'
```

(`class` should match whatever the app sets as `WM_CLASS`'s general class —
confirm what your GTK X11 backend actually sets there, e.g. via
`gtk_window_set_wmclass`/the program's `g_set_prgname`, since `instance`
vs `class` is easy to mix up.)

### `for_window` vs one-off commands — which applies here?

**`for_window` does not apply here.** Per the sway man page text itself:
"Whenever a window that matches _criteria_ appears, run list of commands,"
and the CRITERIA section explicitly frames it as being "used with either
the `for_window` or `assign` commands to specify operations to perform **on
new windows**." That is a one-time rule fired at window-creation time — it
cannot be "re-triggered" later to shrink an already-running, already-mapped
window on demand. Since this feature is a **runtime** shrink/restore toggle
during an already-running app (not a permanent placement policy applied
once at launch), the app must issue one-off `swaymsg`/`i3-msg` commands
over the IPC socket at the exact moment it wants to shrink, and again to
restore — exactly the pattern shown above.

**Sequencing:** the window must already be mapped and known to sway/i3's
tree before these criteria-based commands can match and act on it (they
operate on existing tree containers, found via `GET_TREE`/criteria
matching) — this is a non-issue for our use case since the app is already
running and its window already exists by the time the user reaches a
shortcut-practice step; we are not racing window creation. I was not able
to find a primary-source statement giving hard ordering guarantees between
the `window::new` IPC event and full tree availability (the `sway-ipc(7)`
man page documents the event's existence and its `change` values — `new`,
`close`, `focus`, `title`, `fullscreen_mode`, `move`, `floating`, `urgent`,
`mark` — but not ordering guarantees, and a targeted search of sway's issue
tracker didn't surface a definitive spec statement either). This ordering
question is irrelevant to our shrink/restore feature specifically, since we
act on our own already-mapped window, not on a window we're racing to catch
at creation.

---

## 5. Does XWayland (forcing `GDK_BACKEND=x11`) restore positioning on GNOME/KDE Wayland sessions?

This is the one point where I could **not** get a definitive primary-source
answer, and secondary sources actively disagree with each other on the
scope of the caveats — flagging this as genuinely uncertain rather than
picking a side.

What's clear: XWayland's window manager component (implemented inside the
Wayland compositor — Mutter and KWin both bundle an XWayland WM) really
does speak X11 semantics to XWayland clients, including
`_NET_MOVERESIZE_WINDOW`/`ConfigureRequest`-style position requests, unlike
native Wayland `xdg_toplevel` clients. Search results turned up ecosystem
evidence that positioning-under-XWayland is an active, nontrivial area of
work — e.g. Weston gained "Initial XWayland window positioning support"
patches (referenced via Phoronix forum discussion,
<https://www.phoronix.com/forums/forum/linux-graphics-x-org-drivers/wayland-display-server/914995-initial-xwayland-window-positioning-support-for-weston>)
and there's a long-standing Red Hat bug, "mutter positions windows
differently under wayland" (bugzilla.redhat.com #1282933), both suggesting
XWayland position handling is compositor-specific and has historically had
gaps/inconsistencies compared to native X11 WMs, rather than being a clean
drop-in restoration of X11 semantics. I was **not able to fetch or confirm**
a primary Mutter or KWin source statement that settles: (a) whether an
XWayland client's `ConfigureRequest`/`_NET_MOVERESIZE_WINDOW` for absolute
coordinates is honored as a real placement request, or (b) whether Mutter's
or KWin's window-management policy still vetoes/clamps/re-centers it the
way a Wayland-native client's placement is always compositor-decided.

**Practical implication:** treat `GDK_BACKEND=x11` (running as an XWayland
client under Mutter or KWin's Wayland session) as a **plausible fallback
worth prototyping and testing empirically on both GNOME and KDE**, not as a
verified guarantee. It is very likely to behave closer to genuine X11
positioning than a native Wayland toplevel does (both compositors' XWayland
integrations exist specifically to make legacy X11 apps work with minimal
behavior changes), but I could not find the primary-source text needed to
state "Mutter/KWin never override XWayland client-requested absolute
position" as settled fact. This should be spiked directly (run the app
under `GDK_BACKEND=x11` on a GNOME Wayland session and a Plasma 6 Wayland
session, call `Gdk.Window.move_resize`, observe whether it lands) before
being relied on in the design.

---

## Summary table

| Desktop environment | layer-shell available? | self-positioning (client sets own coords)? | IPC positioning available? | Recommended strategy for this app |
|---|---|---|---|---|
| **sway / wlroots** | Yes — `zwlr_layer_shell_v1` native | Yes, via layer-shell (`gtk_layer_set_anchor`/margins) | Yes — `swaymsg` with `app_id` criteria, one-off at runtime | Keep current gtk-layer-shell approach; it already gives corner placement and doesn't need IPC. IPC (`swaymsg`) is a viable independent fallback if ever needed. |
| **GNOME / Mutter (Wayland)** | **No** (per gtk-layer-shell's own compat list; unverified whether calling init anyway is fatal — check source or test empirically) | **No** — no protocol gives a plain `xdg_toplevel` client absolute coordinates (confirmed against xdg-shell spec); nothing new as of 2026 (`xx-zones` is relative-to-zone and not yet compositor-implemented) | No native WM IPC equivalent to sway/i3 exists for GNOME Shell in the way this doc searched | Call `gtk_layer_is_supported()` (since 0.5) first and gate on it; on GNOME Wayland, fall back to either (a) `GDK_BACKEND=x11`/XWayland and test empirically whether positioning "just works," or (b) redesign the shrink as an in-window visual shrink (resize/restyle the existing toplevel in place) rather than a moved corner tile, since absolute screen placement isn't achievable natively. |
| **KDE Plasma 6 / KWin (Wayland)** | Yes (per gtk-layer-shell's compat list and KDE's own `layer-shell-qt`) — but **EXCLUSIVE keyboard-interactivity support unverified**, and no primary source found confirming/denying an app_id allowlist | No plain-`xdg_toplevel` self-positioning, same as GNOME | No confirmed KWin-equivalent to sway's IPC positioning was found in this research | Keep the gtk-layer-shell path (call `gtk_layer_is_supported()` first as everywhere), but explicitly test `EXCLUSIVE` keyboard-interactivity mode on a real Plasma 6 Wayland session before shipping — this is the one unverified risk flagged in Q1. |
| **X11 (generic)** | N/A (X11 has no layer-shell concept) | **Yes** — `Gdk.Window.move_resize` / `_NET_MOVERESIZE_WINDOW` work natively; the WM doesn't own placement the way Wayland compositors do | Yes — i3: `i3-msg` with `class`/`instance` criteria (no `app_id`); most other X11 WMs have their own equivalents or none needed since raw X11 positioning already works | Keep current `Gdk.Window.move_resize` approach; it already works. For i3 users specifically, `i3-msg` floating/resize/move is an alternative/backup if direct `move_resize` ever proves insufficient (e.g. under an X11 WM that vetoes client-requested geometry). |

**Cross-cutting caveats flagged above, repeated here for visibility:**
- Mutter's `zwlr_layer_shell_v1` issue thread (GNOME/mutter#973) could not be
  read past its static description (JS-rendered GitLab issue page) — open/
  closed state and any recent discussion is unverified.
- Whether `gtk_layer_init_for_window` aborts the process or silently
  degrades on an unsupported compositor is not documented in the header and
  could not be confirmed from source in this pass — verify against
  `gtk-layer-shell.c` or by testing directly.
- KWin's app_id allowlist (if any) for layer-shell, and its support for the
  `EXCLUSIVE` keyboard-interactivity mode specifically, are unverified.
- XWayland positioning behavior under Mutter/KWin (Q5) is the least-verified
  section of this whole doc — treat it as "worth prototyping," not "known
  to work."

---

## Verified in practice

Empirical spike for [#12](https://github.com/DeepanshuPratik/Regolith_Onboarding/issues/12),
run 2026-09-06. Everything below was measured on a running compositor with
throwaway C/GTK3 programs (not committed); the sections above remain the
primary-source research they were.

### Test environment

| | |
|---|---|
| Host session | sway 1.9 (Regolith), Wayland, `WAYLAND_DISPLAY=wayland-1`, `XDG_CURRENT_DESKTOP=Regolith-Wayland:GNOME:sway`, three outputs |
| Nested GNOME | GNOME Shell 46.0 / libmutter 46.2, `dbus-run-session -- gnome-shell --nested --wayland --wayland-display=wayland-spike12`, single 800x600 virtual output (work area 800x568 under a 32px top bar) |
| Toolkit | GTK 3.24.41, gtk-layer-shell 0.8.2, libwayland-client (Ubuntu, stripped) |
| KDE | **not tested** — `kwin_wayland` is not installed on this machine. Every KWin row in the tables above is still unverified. |

**Caveat, stated up front: a nested `gnome-shell` is not a real GNOME session.**
It is the real Mutter compositor running the real GNOME Shell JS, so it is
authoritative about *which Wayland globals Mutter advertises* and about *how
Mutter's window-management and constraint code responds to a client*. It is
**not** authoritative about anything session-shaped: it has one small virtual
output, no session manager, no real seat/GPU path, no user extensions, and its
XWayland only came up after a stub `org.freedesktop.systemd1` was supplied (see
Q4). Findings are marked with a confidence level individually; the ones that
turn on protocol advertisement and on Mutter's constraint engine are solid, the
ones that would differ with multi-monitor/HiDPI/extension setups are not.

---

### Q1. What does `gtk_layer_is_supported()` return?

**Confirmed on both. Confidence: high.**

| Session | `gtk_layer_is_supported()` | `gtk_layer_get_protocol_version()` |
|---|---|---|
| Host sway 1.9 | `TRUE` | `4` |
| Nested GNOME 46 | `FALSE` | `0` |

On nested GNOME the call itself emits a warning before returning:

```
** (spike12app:311102): WARNING **: It appears your Wayland compositor does not
   support the Layer Shell protocol
```

So gating on it is correct but **not silent** — expect one warning line per run
on GNOME. Call it once and cache (the header already warns it may block for a
roundtrip).

A `WAYLAND_DEBUG=1` registry dump of the nested session corroborates the cause
directly: Mutter advertises `xdg_wm_base` (v6), `gtk_shell1` (v5),
`zwp_keyboard_shortcuts_inhibit_manager_v1` (v1), `xdg_activation_v1` (v1),
`zwp_idle_inhibit_manager_v1`, `zwp_text_input_manager_v3`, and so on — and
**no `zwlr_layer_shell_v1` global at all**. That closes the "Mutter implements
no layer-shell" question from Q1 above with a first-hand observation rather
than a README claim.

---

### Q2. What happens if you call `gtk_layer_init_for_window()` anyway? — **it kills the process**

**This is the load-bearing answer: it is FATAL. The process dies with SIGABRT
(exit code 134, core dumped) the moment the window is shown.** Confidence:
high (reproduced on two independently launched nested sessions, and with the
minimal call set).

The failure is *staged*, which is why it looks survivable at first. Verbatim
output, in order:

```
** (spike12app:315153): WARNING **: It appears your Wayland compositor does not support the Layer Shell protocol
gtk_layer_is_supported() = FALSE
gtk_layer_get_protocol_version() = 0
ACTION: calling gtk_layer_init_for_window()
** (spike12app:315153): CRITICAL **: layer_surface_new: assertion 'gtk_wayland_get_layer_shell_global ()' failed
** (spike12app:315153): WARNING **: Falling back to XDG shell instead of Layer Shell (surface should appear but layer features will not work)
SURVIVED: gtk_layer_init_for_window() returned
ACTION: gtk_layer_set_layer(OVERLAY)
** (spike12app:315153): CRITICAL **: Custom wayland shell surface is not a layer surface, your Wayland compositor may not support Layer Shell
SURVIVED: gtk_layer_set_layer() returned
ACTION: gtk_layer_set_keyboard_mode(EXCLUSIVE)
** (spike12app:315153): CRITICAL **: Custom wayland shell surface is not a layer surface, your Wayland compositor may not support Layer Shell
SURVIVED: gtk_layer_set_keyboard_mode() returned
ACTION: gtk_widget_show_all()
<shell>: line 7: 315153 Aborted                 (core dumped) ./probe --layer
exit=134
```

Note what this means: **all three gtk-layer-shell calls return normally.** The
library really does try to degrade — it says so ("Falling back to XDG shell
instead of Layer Shell"). The abort happens later, at map time, inside the
Wayland roundtrip GTK performs while mapping. `gdb` backtrace:

```
#4  __GI_abort ()
#5  ??? () at /lib/x86_64-linux-gnu/libwayland-client.so.0
#6  ??? () at /lib/x86_64-linux-gnu/libwayland-client.so.0
#7  ??? () at /lib/x86_64-linux-gnu/libwayland-client.so.0
#8  wl_display_dispatch_queue_pending ()
#9  wl_display_roundtrip_queue ()
...
#15 gtk_widget_map () at /lib/x86_64-linux-gnu/libgtk-3.so.0
#22 gtk_widget_show () at /lib/x86_64-linux-gnu/libgtk-3.so.0
#23 main ()
```

The last protocol traffic before the abort (`WAYLAND_DEBUG=1`) is the fallback
xdg-shell surface being created and Mutter answering it:

```
 -> wl_compositor@4.create_surface(new id wl_surface@31)
 -> xdg_wm_base@32.get_xdg_surface(new id xdg_surface@33, wl_surface@31)
 -> xdg_surface@33.get_toplevel(new id xdg_toplevel@34)
 -> xdg_toplevel@34.set_title("spike12")
 -> wl_surface@31.commit()
 -> wl_display@1.sync(new id wl_callback@35)
    xdg_toplevel@34.configure_bounds(800, 568)     <-- last event, then abort
```

**Mechanism: probable, not proven.** `libwayland-client` contains exactly one
abort-with-message in that dispatch path — `listener function for opcode %u of
%s is NULL` — and the last event is `xdg_toplevel.configure_bounds`, an
xdg-shell v4 event; gtk-layer-shell binds `xdg_wm_base` at **version 6** on its
own private registry (`wl_registry@30.bind(8, "xdg_wm_base", 6, ...)`) while
taking a fallback code path that sway never exercises. That fits a
missing-listener-entry abort. I could not confirm it: the shipped
libwayland-client is stripped so the abort site would not resolve
symbolically, and no message reached stderr even with a custom
`wl_log_set_handler_client()` handler installed. **Confidence on the exact
cause: low. Confidence that the process dies: high.**

Three further checks, all reproduced:

- **`gtk_layer_init_for_window()` alone is enough.** Skipping `set_layer` and
  `set_keyboard_mode` entirely still aborts with 134. There is no "call init
  but avoid the extras" escape hatch.
- **Both nested sessions behave identically** (exit 134 on `wayland-spike12`
  and `wayland-spike13`), and the same binary exits 0 on host sway.
- **Gating fixes it completely.** The same program, run without the
  layer-shell calls, maps and runs to a clean `exit 0` on nested GNOME.

**Consequence for this repo:** `src/onboardingWindow.vala:153` calls
`GtkLayerShell.init_for_window` unconditionally whenever `IS_SESSION_WAYLAND`.
On GNOME Wayland that is a **hard crash at window-show time**, not a
misbehaviour — the app never draws anything. This is a shipping bug for the
generic-Linux destination, and the fix (gate every layer-shell call on a cached
`gtk_layer_is_supported()`) is mandatory, not a nicety.

---

### Q3. Plain GTK3 window on nested GNOME: size yes, position silently ignored

**Confirmed. Confidence: high.** A 400x300 `GtkWindow`, then one geometry call
per main-loop iteration:

| Step | app-side `gtk_window_get_size()` | app-side `gtk_window_get_position()` | protocol traffic emitted |
|---|---|---|---|
| after map | (400,300) | (23,15) | `set_window_geometry(23, 15, 400, 328)` |
| `gtk_window_resize(200,150)` | **(200,150)** | (23,15) | `attach(buffer)`, `damage(0,0,246,224)`, **`set_window_geometry(23, 15, 200, 178)`** |
| `gtk_window_move(60,60)` | (200,150) | (23,15) | **none — not a single request** |
| `gtk_window_move(500,400)` | (200,150) | (23,15) | **none** |
| `gtk_window_resize(400,300)` | **(400,300)** | (23,15) | `set_window_geometry(23, 15, 400, 328)` |
| `gtk_window_move(0,0)` | (400,300) | (23,15) | **none** |

- **Size: works, both directions, at runtime, on an already-mapped window.**
  The shrink and the restore both reach the compositor.
- **Position: silently ignored, and ignored *client-side*.** `gtk_window_move()`
  produces **zero** Wayland requests — GDK discards it before it ever reaches
  Mutter. No warning, no error, no `g_critical`. Nothing to catch, nothing to
  detect at runtime.
- **The position cannot even be read.** `gtk_window_get_position()` returns a
  constant `(23,15)` — the CSD shadow inset, not a screen coordinate — and
  `gdk_window_get_origin()` returns `(0,0)` throughout. A placer that wants to
  "save the old position and restore it" has nothing to save.
- **The compositor can resize you unasked.** An 800x600 window on this 800x568
  work area was spontaneously sent `configure(800, 568)` with a state array and
  snapped to it. A shrink-to-corner beat must not assume the size it asked for
  is the size it keeps.

---

### Q4. XWayland on Mutter: **yes, client-requested absolute coordinates are honoured**

**Confirmed, subject to Mutter's normal constraint engine. Confidence: high on
nested Mutter 46; medium for a real GNOME session (single 800x600 output here,
no multi-monitor or HiDPI coverage).**

**Setup note worth recording, because it cost the most time here.** Under
`dbus-run-session`, nested gnome-shell *cannot start XWayland at all*:

```
GNOME Shell-Message: Error starting X11 services: GDBus.Error:...Spawn.ChildExited:
    Process org.freedesktop.systemd1 exited with status 1
(gnome-shell): libmutter-WARNING **: Failed to initialize X11 display: Unknown error
```

gnome-shell asks `systemd --user` to bring up
`gnome-session-x11-services.target` before it will let XWayland up, and a
private bus has no systemd. Workaround used: run the nested shell on a
hand-started `dbus-daemon --session` alongside a ~120-line stub owning
`org.freedesktop.systemd1` that answers `GetUnit`/`StartUnit` and reports every
unit `ActiveState = "active"`. With that in place XWayland started normally
(`Using public X11 display :5`) and Mutter registered as the X11 window manager
(`_NET_SUPPORTING_WM_CHECK` → `_NET_WM_NAME = "GNOME Shell"`).

Same test program, `GDK_BACKEND=x11`, geometry sampled from *outside* the
process with `xwininfo` as ground truth. Screen is 800x600; GNOME top bar is
32px:

| Step | app-side pos/size | external `xwininfo` (abs X, abs Y, W, H) | verdict |
|---|---|---|---|
| after map | (199,108) 400x300 | 199, 145, 400, 300 | Mutter placed it |
| `resize(200,150)` | (199,108) **200x150** | 199, 145, **200, 150** | **honoured exactly** |
| `move(60,60)` | **(60,60)** 200x150 | **60, 97**, 200, 150 | **honoured exactly** (abs Y = frame Y + 37px titlebar) |
| `move(500,400)` | **(500,400)** 200x150 | **500, 437**, 200, 150 | **honoured exactly** (fits in the work area) |
| `resize(400,300)` | (400,263) 400x300 | 400, 300, 400, 300 | resize honoured; **constrained** back onscreen, since 500+400 > 800 |
| `move(0,0)` | (0,**32**) 400x300 | 0, 69, 400, 300 | X honoured exactly; Y **clamped to the work area** below the 32px top bar |

Read that table carefully: Mutter is **not** vetoing client placement under
XWayland — it is applying the ordinary X11 window-manager constraint engine.
Requests inside the work area land pixel-exactly. Requests outside it are
*clamped*, not dropped. That is precisely the behaviour a shrink-to-corner
feature needs, provided the target rectangle is computed against the **work
area** (`_NET_WORKAREA` / monitor workarea) rather than the raw screen.

**So `GDK_BACKEND=x11` is a viable fallback for the shrink-to-corner beat on
GNOME, and this materially changes [#17](https://github.com/DeepanshuPratik/Regolith_Onboarding/issues/17):**
GNOME does not have to get a null placer.

Not settled here, and it should be before committing to the XWayland route:
multi-monitor placement, fractional/HiDPI scaling (an XWayland app on a scaled
GNOME output is typically blurry), and the knock-on cost of running the *whole*
app as an X11 client — that also changes the input-grab story, since the
`zwp_keyboard_shortcuts_inhibit_v1` finding in
`keyboard-shortcuts-inhibit.md` applies to Wayland-native clients, not
XWayland ones. Forcing `GDK_BACKEND=x11` to gain placement may cost the
shortcut-inhibitor. **That trade-off is unmeasured and is the next thing to
spike.**

One anomaly, recorded for honesty: on the very first XWayland run, a
`gtk_window_resize()` and `gtk_window_move()` issued in the *same* main-loop
iteration ~2.5s after first map produced the move but dropped the resize. A
later rerun of exactly that combined case worked (resize + move both applied,
in both orders). Treat it as a first-map race rather than a rule, but do apply
geometry only after the window has mapped and settled, and verify the result.

---

### Q5. sway IPC one-off float/resize/move for runtime shrink/restore

**Confirmed on the real host sway 1.9 session. Confidence: high.** Test app
`app_id=spike12geom` (set via `g_set_prgname()` before `gtk_init()`); no
`for_window` rule for that `app_id` exists anywhere in `/etc/regolith/sway/`
or `~/.config/sway/`.

Geometry read back from `swaymsg -t get_tree` after each command:

| Command | resulting `rect` |
|---|---|
| (as mapped, tiled) | (3643, 710, 1712, 700) |
| `[app_id="spike12geom"] floating enable` | (3438, 555, **404, 304**) |
| `[app_id="spike12geom"] resize set 240 px 160 px` | (3520, 627, **240, 160**) |
| `[app_id="spike12geom"] move position 20 px 20 px` | (**1945, 25**, 240, 160) |
| `resize set 400 px 260 px` (repeat, already floating) | (1865, -25, **400, 260**) |
| `move position 600 px 400 px` (repeat) | (**2525, 405**, 400, 260) |
| `resize set 800 px 600 px` + `move position center` | (3240, 407, **800, 600**) |
| `floating disable` | back to a tiled `con` |

Answers to the question as asked:

- **`for_window` rules are not needed.** None existed for this `app_id`; every
  command above acted on the already-mapped window.
- **Repeated resize/move on an already-mapped, already-floating window works.**
  The second `resize set` and second `move position` both landed exactly.
- **The three commands can be issued as one `swaymsg` invocation**,
  comma-chained:
  `swaymsg '[app_id="..."] floating enable, resize set 240 px 160 px, move position 20 px 20 px'`.
  Tested three ways — one chained command, three separate `swaymsg` calls
  back-to-back, and three calls 0.5s apart — all three produced the identical
  final rect `(1945, 25, 240, 160)`. No settling delay is required between
  them.

Two behaviours the sections above did **not** call out, and that a
`WindowPlacer` will get wrong if it doesn't know them:

- **`move position <x> <y>` is workspace-relative, not global.** The focused
  workspace's rect origin was `(1925, 5)`; `move position 20 px 20 px` landed
  the window at `(1945, 25)` = origin + (20,20). `move absolute position
  20 px 20 px` landed it at `(20, 20)` — on a *different output*. For corner
  placement, either use plain `move position` with coordinates derived from the
  focused workspace's rect (`swaymsg -t get_workspaces`), or use `move position
  center`. Do not use `absolute` unless you mean global layout coordinates.
- **`resize set` resizes about the window's centre.** A window pinned at
  `(1945, 25)` and then resized to 400x260 ended up at `(1865, -25)` — partly
  off the top of the output. This is why the order in the sections above is
  right: **resize first, then move**, never the reverse.

For restore, `resize set <orig_w> <orig_h>` followed by `move position center`
(or `floating disable` to hand the window back to the tiling layout) both work.

---

### What this settles for `WindowPlacer` (#17)

| Desktop | Placer | Basis |
|---|---|---|
| sway / wlroots | **IPC placer.** `floating enable` → `resize set` → `move position`, issued as one comma-chained `swaymsg`, coordinates workspace-relative. Restore with `resize set` + `move position center`/`floating disable`. | Q5, real session, high confidence |
| GNOME Wayland (native) | **Resize-only placer at best.** Size changes work; position is unreachable and unreadable. **Must never call any gtk-layer-shell function** — `init_for_window` is fatal at map time. | Q2, Q3, high confidence |
| GNOME via XWayland (`GDK_BACKEND=x11`) | **Real corner placement is available**, clamped to the work area. Viable, but forces the whole app onto XWayland, with unmeasured cost to HiDPI rendering and to the keyboard-shortcuts-inhibitor path. | Q4, high on nested Mutter, medium on real hardware |
| KDE / KWin | **Still unverified.** `kwin_wayland` is not installed on this machine; nothing in this section applies to it. | — |

Unconditional, independent of which placer is chosen: **every gtk-layer-shell
call in the app must be gated on a cached `gtk_layer_is_supported()`.** Today's
unconditional `IS_SESSION_WAYLAND` branch at `src/onboardingWindow.vala:153`
aborts the process on GNOME Wayland.
