# `zwp_keyboard_shortcuts_inhibit` on GNOME/Mutter and KDE/KWin Wayland

**Research date: 2026-09-06.** All load-bearing claims below are cited to a primary source (protocol XML, compositor/toolkit source with file path and line numbers, or an official changelog/commit). Where a claim could only be established by inference, or a primary source could not be located, that is flagged inline rather than asserted as fact.

## Summary

`zwp_keyboard_shortcuts_inhibit_manager_v1` is real, is implemented by **both** Mutter (since GNOME 3.28, January 2018) and KWin (since Plasma 5.20, October 2020), and in both compositors it inhibits *all* window-manager-level shortcuts for the focused surface+seat pair, with a small number of explicit, source-confirmed carve-outs (a restore keybinding and VT-switching on Mutter; none found beyond the power key on KWin). The most consequential finding for this app, however, is about GTK3: **GTK3's Wayland backend already speaks this protocol internally**, and it does so automatically, with no manual protocol binding required, the moment an app calls the ordinary portable `Gdk.Seat.grab()`/`Gdk.Device.grab()` API with a keyboard-only capability on a toplevel window — the exact call this app already makes on X11. This is not a theoretical reading of the source: `spice-gtk` (the display widget behind `virt-viewer`/`remote-viewer` and GNOME Boxes) does precisely this, and is real-world, shipping prior art for a GTK3 app getting "grab all keys" on Wayland through the portable API alone. The catch is that GTK3 wires up *only* the request/destroy half of the protocol — it never listens for the `active`/`inactive` events, so a GTK3 app has no way to know whether a compositor's permission dialog was accepted, denied, or later revoked; it must infer that from whether keys are actually arriving. GTK4 closes this gap with a first-class, documented, portable API (`Gdk.Toplevel.inhibit_system_shortcuts`) that does listen for `active`/`inactive`.

---

## 1. Protocol semantics

**Primary source:** the protocol XML itself, read from the locally installed `wayland-protocols` package (`/usr/share/wayland-protocols/unstable/keyboard-shortcuts-inhibit/keyboard-shortcuts-inhibit-unstable-v1.xml`, part of `wayland-protocols` 1.45 per `pkg-config --modversion wayland-protocols`), and confirmed byte-identical against `https://gitlab.freedesktop.org/wayland/wayland-protocols/-/raw/main/unstable/keyboard-shortcuts-inhibit/keyboard-shortcuts-inhibit-unstable-v1.xml`. As of that `main` branch, the protocol is still under `unstable/` — no `stable/` promotion or version-2 bump has happened.

**What gets inhibited:** the description on `zwp_keyboard_shortcuts_inhibitor_v1` is unambiguous that this is meant to be *all* compositor shortcuts, not a curated subset:

> "A keyboard shortcuts inhibitor instructs the compositor to ignore its own keyboard shortcuts when the associated surface has keyboard focus. As a result, when the surface has keyboard focus on the given seat, it will receive all key events originating from the specified seat, even those which would normally be caught by the compositor for its own shortcuts."

The protocol does **not** enumerate a fixed set of exempt shortcuts. Instead it explicitly reserves the compositor's right to keep some of its own:

> "The Wayland compositor is however under no obligation to disable all of its shortcuts, and may keep some special key combo for its own use, including but not limited to one allowing the user to forcibly restore normal keyboard events routing in the case of an unwilling client. The compositor may also use the same key combo to reactivate an existing shortcut inhibitor that was previously deactivated on user request."

So the carve-out is compositor policy, not protocol law — see §2/§3 for what Mutter and KWin actually chose.

**Refusal:** the *manager*'s `inhibit_shortcuts` request has exactly one defined error, `already_inhibited` — "If shortcuts are already inhibited for the specified seat and surface, a protocol error 'already_inhibited' is raised by the compositor." There is no protocol-level "permission denied" error; a compositor that wants to gate the request behind a user-consent dialog (Mutter does — see §2) has to do so out-of-band and then simply never send `active`, or send `inactive` immediately. The protocol gives clients no structured way to distinguish "denied by policy" from "not yet focused."

**`active`/`inactive` event semantics:**
- `active` — "The compositor sends this event every time compositor shortcuts are inhibited on behalf of the surface... This occurs typically when the initial request 'inhibit_shortcuts' first becomes active or when the user instructs the compositor to re-enable an existing shortcuts inhibitor."
- `inactive` — "This event indicates that the shortcuts inhibitor is inactive, normal shortcuts processing is restored by the compositor."
- Critically: **"If the surface is destroyed, unmapped, or loses the seat's keyboard focus, the keyboard shortcuts inhibitor becomes irrelevant and the compositor will restore its own keyboard shortcuts but no 'inactive' event is emitted in this case."** Ordinary focus loss is silent at the protocol level — see §7.

**Scoping:** `inhibit_shortcuts` is a request on the manager that takes both a `wl_surface` and a `wl_seat` as arguments, and creates one `zwp_keyboard_shortcuts_inhibitor_v1` object per call — so yes, an inhibitor is scoped to exactly one surface+seat pair, and a second `inhibit_shortcuts` call for the same pair is the `already_inhibited` error case above.

---

## 2. Mutter (GNOME) support

**Implemented, since GNOME 3.28 (landed January 2018).** Primary sources:

- The RFC/tracking bug, **`bugzilla.gnome.org` #783342**, "Wayland: RFC - add xwayland keyboard grab / shortcut inhibitor support" (<https://bugzilla.gnome.org/show_bug.cgi?id=783342>), status **RESOLVED FIXED**. The bug's own comment log links the landing commits directly, e.g. "wayland: add inhibit shortcut mechanism" and "wayland: add keyboard shortcuts inhibitor protocol" on mutter master, plus "core: add MetaInhibitShortcutsDialog" / "ui: Add InhibitShortcutsDialog" on gnome-shell — all dated January 2018, i.e. in time for the GNOME 3.28 cycle (released March 2018).
- The actual dispatch/gatekeeping code today lives in `src/core/keybindings.c` on the mutter `main` branch (fetched via `https://gitlab.gnome.org/GNOME/mutter/-/raw/main/src/core/keybindings.c`), confirmed present and current as of this research pass.
- The inhibitor's own request/lifecycle plumbing lives in `src/wayland/meta-wayland-inhibit-shortcuts.c` (confirmed to exist at `https://github.com/GNOME/mutter/blob/main/src/wayland/meta-wayland-inhibit-shortcuts.h` and mirrored on gitlab.gnome.org); it requires the requesting surface to already have an associated toplevel window (`meta_wayland_surface_get_toplevel_window (surface)`), otherwise it shows/uses the inhibit-shortcuts-dialog path rather than activating immediately — an early commit message on this exact code is literally titled **"wayland: shortcuts inhibitor requires a window"** (mutter commits-list, January 2018).

**Consent dialog and app allowlist — confirmed from source.** GNOME Shell's `js/ui/inhibitShortcutsDialog.js` (fetched from `https://gitlab.gnome.org/GNOME/gnome-shell/-/raw/main/js/ui/inhibitShortcutsDialog.js`) implements `Meta.InhibitShortcutsDialog` and shows the "The app %s wants to inhibit shortcuts" prompt with Allow/Deny buttons — **except**:

```js
const APP_ALLOWLIST = ['org.gnome.Settings.desktop'];
...
vfunc_show() {
    if (this._app && APP_ALLOWLIST.includes(this._app.get_id())) {
        this._emitResponse(DialogResponse.ALLOW);
        return;
    }
    ...
```
— only the Settings app is silently allowed; everything else gets the dialog (or, if the app has previously been granted/denied, the answer is looked up from the freedesktop **PermissionStore** (`APP_PERMISSIONS_TABLE = 'gnome'`, `APP_PERMISSIONS_ID = 'shortcuts-inhibitor'`) and applied without re-prompting). **This means the onboarding app, as a normal third-party GTK3 app, will hit this consent dialog on first run under GNOME/Mutter Wayland** unless it is added to `APP_ALLOWLIST` (upstream change) or the permission is pre-seeded in the store — there is no way around it at the protocol level from the client side.

**Carve-outs — confirmed by source, and more precise than commonly assumed.** `src/core/keybindings.c` gates every keybinding dispatch on `meta_window_shortcuts_inhibited()`, *except* bindings explicitly flagged `META_KEY_BINDING_NON_MASKABLE`:

```c
if (display->focus_window &&
    !(binding->handler->flags & META_KEY_BINDING_NON_MASKABLE))
  {
    ...
    if (meta_window_shortcuts_inhibited (display->focus_window, source))
      goto not_found;
  }
```
(`src/core/keybindings.c`, mutter `main`, around line 1449 in this pass's fetch.) The keybinding table further down the same file marks exactly these as `META_KEY_BINDING_NON_MASKABLE` (line numbers as fetched in this pass):

```c
{ "restore-shortcuts", META_KEY_BINDING_NON_MASKABLE, META_KEYBINDING_ACTION_NONE, handle_restore_shortcuts, 0 },     // line 2661
{ "switch-to-session-1"  ... 12, META_KEY_BINDING_NON_MASKABLE, ... handle_switch_vt, 1..12 },                        // lines 2665-2676
```
i.e. **only two categories bypass the inhibitor: the `restore-shortcuts` escape hatch and the twelve VT-switch bindings.** The default keybindings for both are in `data/org.gnome.mutter.wayland.gschema.xml.in` (`https://gitlab.gnome.org/GNOME/mutter/-/raw/main/data/org.gnome.mutter.wayland.gschema.xml.in`):
```xml
<key name="restore-shortcuts" type="as"><default><![CDATA[['<Super>Escape']]]></default></key>
<key name="switch-to-session-1" type="as"><default><![CDATA[['<Primary><Alt>F1']]]></default></key>
... (through switch-to-session-12, <Primary><Alt>F12)
```
This matches the well-known user-facing message ("You can restore shortcuts by pressing Super+Escape") that `inhibitShortcutsDialog.js` builds dynamically from `Meta.prefs_get_keybinding_label('restore-shortcuts')`.

**Notably, the plain Super-key-alone Activities-overview trigger is *not* on this carve-out list.** The overlay-key handler, `process_overlay_key()` in the same file, also calls `meta_window_shortcuts_inhibited()` and returns `FALSE` (does not trigger Activities) when the focused window's shortcuts are inhibited. **This directly contradicts the common assumption that Mutter always reserves bare-Super for the overview even while an app has inhibited shortcuts** — per this source, it does not; only `Super+Escape` (restore) and `Ctrl+Alt+F1-12` (VT switch) survive an active inhibitor.

**Known bug affecting the `active` event specifically:** GNOME/mutter issue (surfaced in this pass as "keyboard shortcuts inhibitor 'active' not sent") states Mutter only sends `active` when the surface has keyboard focus, which the reporter argues is a deviation from the spec's "every time compositor shortcuts are inhibited" wording. **I was not able to confirm from the issue tracker whether this was fixed or is still open as of this pass** — the GitLab issue page only yielded a summary via the fetch tool, not a definitive resolved/open status or the linked MR; treat "active-event timing on Mutter" as an area to verify empirically rather than rely on the spec's literal text.

---

## 3. KWin (KDE Plasma) support

**Implemented, since Plasma 5.20.0 (released October 2020).** Primary source: the official KDE changelog page `https://kde.org/announcements/changelogs/plasma/5/5.19.5-5.20.0/`, which under the KWayland-Server component lists, verbatim:

> "Add keyboard_shortcuts_inhibit protocol. [Commit.](https://commits.kde.org/kwayland-server/4a5984a089757a1a318fe8d440c4b8d58c06ed94) Phabricator Code review [D29231](https://phabricator.kde.org/D29231)"
> "Fix class names for keyboard shortcuts inhibit. [Commit.](https://commits.kde.org/kwayland-server/f3308e09a68c92ddba4de86f65b898461af0dc54)"

That commit hash redirects (301) from `commits.kde.org` to `https://invent.kde.org/plasma/kwayland-server/-/commit/4a5984a089757a1a318fe8d440c4b8d58c06ed94`, KDE's own GitLab — a first-party source, not a mirror.

**Where it lives today:** `kwayland-server` was later folded directly into KWin. The live implementation is `src/wayland/keyboard_shortcuts_inhibit_v1.cpp` on the KWin `master` branch (fetched via `https://invent.kde.org/plasma/kwin/-/raw/master/src/wayland/keyboard_shortcuts_inhibit_v1.cpp`), still carrying its original 2020 author header:
```cpp
/*
    SPDX-FileCopyrightText: 2020 Benjamin Port <benjamin.port@enioka.com>
    ...
*/
```

**Refusal / consent:** unlike Mutter, **KWin's protocol-layer implementation shows no consent dialog and no allowlist at all** — `inhibit_shortcuts` is granted unconditionally the instant it's requested:
```cpp
void KeyboardShortcutsInhibitManagerV1InterfacePrivate::zwp_keyboard_shortcuts_inhibit_manager_v1_inhibit_shortcuts(...)
{
    ...
    if (m_inhibitors.contains({surface, seat})) {
        wl_resource_post_error(resource->handle, error::error_already_inhibited, ...);
        return;
    }
    ...
    inhibitor->setActive(true);   // <- unconditional; no dialog, no allowlist check here
}
```
(`src/wayland/keyboard_shortcuts_inhibit_v1.cpp`, KWin `master`.) **I searched specifically for a KDE equivalent of Mutter's `InhibitShortcutsDialog`/permission-store flow (a "wants to inhibit shortcuts" prompt) and did not find one** in KWin, plasma-workspace, or KDE discussion/bug threads surfaced by this pass — this should be treated as "not found," not as confirmation that no such prompt exists anywhere in the stack (e.g., a portal-level prompt is plausible but unverified).

**How the inhibition is actually enforced, and its focus-scoping:** `src/wayland_server.cpp`:
```cpp
bool WaylandServer::isKeyboardShortcutsInhibited() const
{
    auto surface = seat()->focusedKeyboardSurface();
    if (surface) {
        auto inhibitor = keyboardShortcutsInhibitManager()->findInhibitor(surface, seat());
        if (inhibitor && inhibitor->isActive()) {
            return true;
        }
        ...
    }
    return false;
}
```
This is checked directly in the keyboard input path, `src/keyboard_input.cpp:287` and `src/input.cpp` (lines ~1077, ~1084 in this pass's fetch), immediately before global-shortcut dispatch (`input()->shortcuts()->processKey(...)`).

**Carve-outs found:** the only hardcoded bypass located in this pass is the **power key**. In `src/input.cpp`, the `Qt::Key_PowerOff` branch is handled in a separate `if` *before* the `isKeyboardShortcutsInhibited()` check that gates everything else, so long-press-power/shutdown handling is unconditional regardless of an active inhibitor. **No Meta/Super-key-specific carve-out or restore/escape keybinding equivalent to Mutter's `restore-shortcuts` was found in KWin source or KDE documentation in this pass** — if KWin has one, it was not located; do not assume parity with Mutter's Super+Escape behavior without testing on a real Plasma Wayland session.

---

## 4. sway/wlroots support

**Implemented in wlroots, consumed by sway since Sway 1.5.** Primary sources, both from `swaywm` GitHub (the project's own canonical repo, not a mirror):

- wlroots side: `types/wlr_keyboard_shortcuts_inhibit_v1.c` and `include/wlr/types/wlr_keyboard_shortcuts_inhibit_v1.h` (`https://github.com/swaywm/wlroots/blob/master/types/wlr_keyboard_shortcuts_inhibit_v1.c`), landed via wlroots PR #2026 ("Keyboard shortcuts inhibit" by michaelweiser). This is bare protocol machinery: it refuses a second `inhibit_shortcuts` for the same surface+seat (posts the `already_inhibited` error), and exposes `wlr_keyboard_shortcuts_inhibitor_v1_activate()`/`_deactivate()` for the compositor to call — **it does not itself tie activation to focus or hardcode any carve-out**; all of that policy is left to the compositor (sway) using the library.
- sway side: commit `eeac0aa170d4ee19111df072ea361b56c802cf34`, "input: Add support for keyboard shortcuts inhibit" (`https://github.com/swaywm/sway/commit/eeac0aa170d4ee19111df072ea361b56c802cf34`, landed via sway PR #5021, same author), which touches `sway/input/input-manager.c`, `sway/input/seat.c`, `sway/input/keyboard.c`, and `sway/commands/bind.c`.

**Carve-out mechanism (config-level, not hardcoded):** sway's own docs (`sway/sway.5.scd`, added in the same commit) describe a `--inhibited` bind flag: "The `--inhibited` flag allows to define bindings which will be exempt from pass-through to such software," used like `bindsym --inhibited $mod+Escape seat - shortcuts_inhibitor deactivate`. Unlike Mutter/KWin, **sway ships with no default carve-out at all** — an inhibited sway session forwards literally everything to the client unless the user has explicitly configured an `--inhibited` binding in their own config. **Focus-loss behavior:** the same docs state "The inhibitor can be deactivated by the user by removing focus from the surface using another input device such as the pointer" — consistent with the protocol's own focus-loss language in §1/§7.

---

## 5. GTK3 reachability

**This is the most important finding for this app's design, and it runs opposite to the premise that manual protocol binding is required.**

### GTK3: no public API, but automatic internal wiring through the ordinary grab API

I fetched GTK3's actual Wayland backend source directly (`gtk-3-24` branch, `https://gitlab.gnome.org/GNOME/gtk/-/raw/gtk-3-24/...`) rather than relying on documentation, because a WebSearch-surfaced GNOME bug (mutter/gnome-shell issue "Keyboard not grabbed in Settings' keyboard panel") claimed GTK+ calls a function named `gdk_wayland_window_inhibit_shortcuts()`. That function exists, at `gdk/wayland/gdkwindow-wayland.c:5849` on `gtk-3-24`:

```c
void
gdk_wayland_window_inhibit_shortcuts (GdkWindow *window,
                                      GdkSeat   *gdk_seat)
{
  GdkWindowImplWayland *impl= GDK_WINDOW_IMPL_WAYLAND (window->impl);
  GdkWaylandDisplay *display = GDK_WAYLAND_DISPLAY (gdk_window_get_display (window));
  struct wl_surface *surface = impl->display_server.wl_surface;
  struct wl_seat *seat = gdk_wayland_seat_get_wl_seat (gdk_seat);
  struct zwp_keyboard_shortcuts_inhibitor_v1 *inhibitor;

  if (display->keyboard_shortcuts_inhibit == NULL)
    return;
  if (gdk_wayland_window_get_inhibitor (impl, seat))
    return; /* Already inhibitted */

  inhibitor =
      zwp_keyboard_shortcuts_inhibit_manager_v1_inhibit_shortcuts (
          display->keyboard_shortcuts_inhibit, surface, seat);
  g_hash_table_insert (impl->shortcuts_inhibitors, seat, inhibitor);
}
```
and its counterpart `gdk_wayland_window_restore_shortcuts()` at line 5872, which destroys the inhibitor object.

**But this function is not declared in the public header `gdk/wayland/gdkwaylandwindow.h`** (checked directly — every other backend-specific Wayland entry point in GTK3, e.g. `gdk_wayland_window_set_application_id`, `gdk_wayland_window_announce_ssd`, is declared there with a `GDK_AVAILABLE_IN_3_2x` annotation; `inhibit_shortcuts`/`restore_shortcuts` are absent from that header entirely). There is also no portable `gdk_window_inhibit_shortcuts()` in generic `gdk/gdkwindow.h`/`gdk/gdkwindow.c` (checked directly — no match). **In other words: GTK3 does not expose this to applications as a documented, callable API at all**, backend-specific or portable.

**Instead, GTK3 calls it internally, automatically, from its own generic (cross-platform) grab implementation**, in `gdk/wayland/gdkdevice-wayland.c`. Two call sites, both confirmed by direct source fetch:

1. `gdk_wayland_device_grab()` (the backend behind the portable `gdk_device_grab()`), line 922:
```c
if (gdk_device_get_source (device) == GDK_SOURCE_KEYBOARD)
  {
    if (gdk_window_get_window_type (window) == GDK_WINDOW_TOPLEVEL)
      gdk_wayland_window_inhibit_shortcuts (window, gdk_device_get_seat (device));
    return GDK_GRAB_SUCCESS;
  }
```
2. The seat-grab path (behind the portable `gdk_seat_grab()`), line 5174:
```c
/* Inhibit shortcuts on toplevels if the seat grab is for the keyboard only */
if (capabilities == GDK_SEAT_CAPABILITY_KEYBOARD &&
    native->window_type == GDK_WINDOW_TOPLEVEL)
  gdk_wayland_window_inhibit_shortcuts (window, seat);
```
Note the **exact-equality** check: `capabilities == GDK_SEAT_CAPABILITY_KEYBOARD`. A grab that asks for keyboard *and* pointer capability together will **not** trigger this path — only a pure keyboard-only grab does.

Restoration is symmetric, on ungrab, in `gdk_wayland_device_ungrab()` (line ~968) and the seat-ungrab path (line ~5232) — both call `gdk_wayland_window_restore_shortcuts()` for the previously-focused window.

**GTK3 registers no listener for the `active`/`inactive` events at all** — confirmed by exhaustive grep of `gdkwindow-wayland.c` for `add_listener`; the only symbols present are the request-side calls above. A GTK3 app therefore has no callback, property, or signal telling it whether the compositor actually honored the inhibit request (e.g., Mutter's consent dialog was denied) or later revoked it — it can only infer this from whether expected keys are actually arriving.

**Practical consequence for this app on GTK3:** calling the ordinary, already-used **`Gdk.Seat.grab(seat, window, Gdk.SeatCapabilities.KEYBOARD, ...)`** on a normal (non-layer-shell) toplevel window, on Wayland, under a compositor that implements this protocol, **automatically issues a `zwp_keyboard_shortcuts_inhibit_manager_v1.inhibit_shortcuts` request with no additional Wayland/protocol code required** — provided the capability argument is keyboard-only, not combined with pointer. No manual `wl_registry`/`wl_display_get_registry` binding is needed for this specific mechanism to fire; GDK already did the registry bind (see below) and the dispatch. What manual binding *would* buy you, that GTK3's private wiring does not, is the `active`/`inactive` feedback signal itself.

**The registry-bind side**, for completeness (`gdk/wayland/gdkdisplay-wayland.c`, around line 522):
```c
else if (strcmp (interface, "zwp_keyboard_shortcuts_inhibit_manager_v1") == 0)
  {
    display_wayland->keyboard_shortcuts_inhibit =
      wl_registry_bind (display_wayland->wl_registry, id,
                        &zwp_keyboard_shortcuts_inhibit_manager_v1_interface, 1);
  }
```
This runs unconditionally for every GTK3 Wayland client, whether or not the app ever calls a grab — so the manager object is always available in `GdkWaylandDisplay` if the compositor advertises the global at all.

**If manual binding were still wanted anyway** (e.g. to get the `active`/`inactive` events GTK3 doesn't surface), the concrete steps, using only public GDK entry points, would be:
1. Get the `wl_display`: `gdk_wayland_display_get_wl_display (display)`.
2. Either reuse GDK's already-bound manager (not exposed publicly — private field of `GdkWaylandDisplay`) or do your own `wl_display_get_registry()` + a `wl_registry_listener` and bind `zwp_keyboard_shortcuts_inhibit_manager_v1` yourself, independently of GDK's internal one (two separate client-side bindings of the same global is legal Wayland).
3. Get the surface: `gdk_wayland_window_get_wl_surface (gtk_widget_get_window (window))`.
4. Get the seat: `gdk_wayland_seat_get_wl_seat (gdk_seat)` from `gdk_display_get_default_seat()`.
5. Call `zwp_keyboard_shortcuts_inhibit_manager_v1_inhibit_shortcuts(manager, surface, seat)` to get a `zwp_keyboard_shortcuts_inhibitor_v1*`.
6. Add a listener via `zwp_keyboard_shortcuts_inhibitor_v1_add_listener()` for `active`/`inactive`, and act on them (e.g., show your own "shortcuts inhibited" / "shortcuts lost" UI state).
7. `zwp_keyboard_shortcuts_inhibitor_v1_destroy()` when done.

Given that step 2 (manager access) is the only piece not already reachable through public GDK API, and that the automatic-wiring path already gets the actual inhibition without any of this — the pragmatic reading is: **do manual binding only if you specifically need the `active`/`inactive` signal**; otherwise a plain keyboard-only `Gdk.Seat.grab()` already does the job on any compositor implementing the protocol.

### GTK4: proper, documented, portable public API — and it does listen for the events

GTK4 promotes this to a first-class, documented, backend-agnostic API: **`Gdk.Toplevel.inhibit_system_shortcuts()`**, documented at `https://docs.gtk.org/gdk4/method.Toplevel.inhibit_system_shortcuts.html` (source link on that page: `gdk/gdktoplevel.c:643`). Confirmed by direct source fetch of GTK4's Wayland backend (`https://gitlab.gnome.org/GNOME/gtk/-/raw/main/gdk/wayland/gdktoplevel-wayland.c`):

```c
static gboolean
gdk_wayland_toplevel_inhibit_system_shortcuts (GdkToplevel *toplevel, GdkEvent *event)  // ~line 1954
{
  ...
  gdk_wayland_surface_inhibit_shortcuts (surface, gdk_seat);
  ...
  zwp_keyboard_shortcuts_inhibitor_v1_add_listener
    (inhibitor, &zwp_keyboard_shortcuts_inhibitor_listener, toplevel);   // <- GTK4 DOES listen
  ...
}
...
iface->inhibit_system_shortcuts = gdk_wayland_toplevel_inhibit_system_shortcuts;  // ~line 2425
```
and the listener callbacks (~line 1870) set a `shortcuts_inhibited` boolean that backs a real, documented `GdkToplevel:shortcuts-inhibited` property clients can bind/watch. So GTK4 both exposes the call as public API on every platform (not Wayland-only, per the `GdkToplevel` vtable) *and* surfaces the missing feedback signal GTK3 never wired up. **This app is GTK3, so it does not get this API — the automatic-wiring behavior described above for GTK3 is what's actually available to it.**

---

## 6. Prior art

**virt-viewer / remote-viewer, via `spice-gtk` — real, concrete, GTK3 precedent for the exact mechanism in §5.** `spice-gtk`'s display widget (`src/spice-widget.c`, fetched from `https://gitlab.freedesktop.org/spice/spice-gtk/-/raw/master/src/spice-widget.c`) grabs the keyboard using nothing but the portable GDK API:

```c
status = gdk_seat_grab(spice_display_get_default_seat(display),
                       gtk_widget_get_window(widget),
                       GDK_SEAT_CAPABILITY_KEYBOARD,
                       FALSE, NULL, NULL, NULL, NULL);
```
(`src/spice-widget.c`, function `try_keyboard_grab`, and mirrored again in the ungrab/regrab path a few hundred lines later). This is **exactly** the keyboard-only-capability call that GTK3's Wayland backend auto-translates into `inhibit_shortcuts` (§5) — spice-gtk does not bind the Wayland protocol itself anywhere in this file, and does not need to. The widget's Wayland-specific code elsewhere in the same file (guarded by `GDK_WINDOWING_WAYLAND`/`HAVE_WAYLAND_PROTOCOLS`) is for a *different* protocol (`spice_wayland_extensions_lock_pointer`/relative-pointer, i.e. pointer confinement), not for shortcuts-inhibit — confirming shortcuts-inhibit specifically rides on the plain `gdk_seat_grab()` call alone. Real-world corroboration that this actually surfaces Mutter's consent UI in practice: Red Hat Bugzilla #1668036, "'Virtual Machine Manager wants to inhibit shortcuts' prompt," and Red Hat Bugzilla #1528653, "Application wants to inhibit shortcuts" (both titles describing exactly the GNOME Shell dialog from §2).

**GNOME Boxes** — its display widget (`src/display-page.vala`, `https://gitlab.gnome.org/GNOME/gnome-boxes/-/raw/main/src/display-page.vala`) exposes `keyboard_grabbed`/`mouse_grabbed`/`can_grab_mouse` properties and reacts to their `notify` signals, but the actual grab call lives in the display backend object it wraps (the SPICE path uses the same `spice-gtk` `SpiceDisplay` widget described above). **I did not find Boxes reimplementing shortcuts-inhibit itself** — it inherits whatever its underlying display widget does, which for its SPICE backend is the spice-gtk mechanism above. I did not check Boxes' RDP-backend display widget in this pass.

**Looking Glass** — **not confirmed either way in this pass.** WebSearch surfaced Looking Glass's own GitHub issue #26 ("Keyboard Capture Mode") discussing the general problem of capturing hotkeys destined for the window manager, but I could not locate (via WebSearch, without a working code-search tool for this repo) an actual source file in `gnif/LookingGlass` binding `zwp_keyboard_shortcuts_inhibit_manager_v1` or calling a GDK/GTK equivalent. Given Looking Glass's client is not GTK-based (it's a custom EGL/SDL-style client per its own docs), if it does use this protocol it would necessarily be via direct/manual `wl_registry` binding, not toolkit auto-wiring — but this is speculation, not a confirmed finding. **Flagged as unresolved.**

**Waypipe** — **no evidence found that it implements or specially handles this protocol**, and this is plausible on its face: waypipe is a transparent Wayland proxy (forwards protocol messages between a remote client and the local compositor), so a client behind waypipe that itself binds `zwp_keyboard_shortcuts_inhibit_manager_v1` would likely have its requests proxied through transparently like any other global, without waypipe needing bespoke handling. **I did not find a primary source (changelog, source comment, or issue) confirming this either way** — flagged as inferred-plausible, not confirmed.

**GNOME Remote Desktop** — **not investigated in this pass.** It sits on the server/host side of a remote-desktop session (implementing the RDP/VNC server that Mutter's compositor process hosts), which is architecturally a different problem (accepting remote input, not locally inhibiting shortcuts for a client surface) — flagged as likely-not-applicable but not verified.

---

## 7. Focus dependency

**Yes — activation is tied to keyboard focus of the requesting surface, at the protocol level, and this is enforced independently (and slightly differently in emphasis) by both Mutter and KWin.**

**Protocol text (§1, repeated here for this question specifically):** "A keyboard shortcuts inhibitor instructs the compositor to ignore its own keyboard shortcuts **when the associated surface has keyboard focus**." And, on losing focus: **"If the surface is destroyed, unmapped, or loses the seat's keyboard focus, the keyboard shortcuts inhibitor becomes irrelevant and the compositor will restore its own keyboard shortcuts but no 'inactive' event is emitted in this case."** This is the load-bearing sentence for the ydotool-spawns-a-terminal scenario: **the moment focus moves to the newly spawned terminal, the compositor silently restores its own shortcuts for this app's surface — and, per the protocol text, sends no `inactive` event to tell the app so.** (GTK3 would not have been listening for that event anyway, per §5.)

**KWin enforces this exactly as the protocol describes, confirmed from source** (`src/wayland_server.cpp:773`, quoted in full in §3): `isKeyboardShortcutsInhibited()` looks up `seat()->focusedKeyboardSurface()` first, and only then checks whether *that specific surface* has an active inhibitor for the seat. If focus has moved to another surface (e.g., a newly spawned terminal), the check trivially fails for the old surface and KWin's global shortcuts resume firing — with no special code needed to "notice" the focus change, because the focus lookup is inline in the same function.

**Mutter's dispatch code in `src/core/keybindings.c` similarly gates on `display->focus_window`** (`if (display->focus_window && !(NON_MASKABLE)) { ... meta_window_shortcuts_inhibited (display->focus_window, source) ... }`) — the inhibited-check is only ever consulted against the currently-focused window, so the same reasoning applies: once focus moves off this app's surface, its inhibitor is no longer the one being consulted.

**Practical implication called out explicitly for this app's design:** if the onboarding app's own ydotool-replay step causes a new window (e.g., a spawned terminal) to take keyboard focus, **the shortcuts-inhibitor protection is gone the instant that happens, on both Mutter and KWin, silently** — matching what the protocol text promises/warns about. Any design relying on this mechanism needs to either (a) keep focus on the onboarding app's own surface for the duration of the practice step and only briefly hand off, re-grabbing afterward, or (b) treat the loss of inhibition as an expected, silent event and re-issue `inhibit_shortcuts` (or, on GTK3, re-call the keyboard-only `Gdk.Seat.grab()`) once focus returns, rather than assuming a callback will fire to say so.

---

## Summary table

| Compositor | Implements? | Since version | Carve-outs | Reachable from GTK3? |
|---|---|---|---|---|
| **Mutter (GNOME)** | **Yes**, confirmed via bugzilla.gnome.org #783342 (RESOLVED FIXED, Jan 2018) and live source in `src/core/keybindings.c` / `src/wayland/meta-wayland-inhibit-shortcuts.c` on mutter `main`. | GNOME/mutter **3.28** (March 2018 release; landing commits dated Jan 2018). | Confirmed from source: only `restore-shortcuts` (default `Super+Escape`) and `switch-to-session-1..12` (`Ctrl+Alt+F1-F12`) are flagged `META_KEY_BINDING_NON_MASKABLE` and bypass the inhibitor. Bare-Super (Activities overview) is **not** exempt — it is inhibited like any other binding, per `process_overlay_key()`. A per-app consent dialog (`inhibitShortcutsDialog.js`) gates activation, except `org.gnome.Settings.desktop` (hardcoded allowlist) and previously-decided apps (via the freedesktop PermissionStore). | **Yes, automatically** — a plain, already-used `Gdk.Seat.grab(..., Gdk.SeatCapabilities.KEYBOARD, ...)` on a toplevel triggers GTK3's private `gdk_wayland_window_inhibit_shortcuts()` internally; no manual protocol binding needed for inhibition itself, only for consuming the `active`/`inactive` feedback GTK3 never wires up. |
| **KWin (KDE Plasma)** | **Yes**, confirmed via KDE's own changelog (`kde.org/announcements/changelogs/plasma/5/5.19.5-5.20.0/`) linking a `commits.kde.org` → `invent.kde.org` first-party commit, and live source in `src/wayland/keyboard_shortcuts_inhibit_v1.cpp` / `src/wayland_server.cpp` / `src/keyboard_input.cpp` on KWin `master`. | Plasma **5.20.0** (October 2020), originally in the now-merged `kwayland-server` component. | Only carve-out found in this pass: `Qt::Key_PowerOff` handling in `src/input.cpp`, which runs before the inhibited-check entirely. **No consent dialog or app allowlist found** in KWin's own protocol-layer code (activation is unconditional) — unlike Mutter. **No Super/Meta-specific or restore-keybinding carve-out was found**; treat KWin's carve-out surface as narrower/unverified-beyond-power-key rather than assume Mutter-equivalent behavior. | Same automatic-wiring answer as Mutter — GTK3's behavior is compositor-agnostic; it depends only on the compositor advertising the global, which KWin does since 5.20. |
| **sway / wlroots** | **Yes**, confirmed via wlroots PR #2026 (`types/wlr_keyboard_shortcuts_inhibit_v1.c`) and sway commit `eeac0aa17` / PR #5021, both on the canonical `swaywm` GitHub repos. | Sway **1.5**. | No default carve-out at all — sway forwards everything unless the user configures their own `bindsym --inhibited ...` in their config (opt-in, not shipped by default). Deactivates on pointer-driven focus loss per sway's own docs. | Same automatic-wiring mechanism would apply in principle, but **this app currently uses gtk-layer-shell's `EXCLUSIVE` keyboard-interactivity mode on sway instead** (per the existing architecture), not this protocol — not exercised by this app on sway today. |
| **X11 (generic)** | N/A — this is a Wayland-only protocol. | — | — | N/A; this app already uses `Gdk.Seat.grab` directly on X11 through ordinary X11 grab semantics, unrelated to this protocol. |

### Open items not resolved by this pass
- Whether Mutter's `active` event is genuinely sent only-on-focus (a possible spec deviation flagged in a GNOME issue surfaced during this research) could not be confirmed as fixed or still-open from the issue tracker alone — verify empirically.
- No KDE-side consent-dialog equivalent to Mutter's was found; this was searched for specifically and not merely omitted.
- Looking Glass and waypipe's relationship (if any) to this specific protocol is unconfirmed either way — flagged, not guessed.
- GNOME Boxes' non-SPICE (RDP) display backend was not checked.

---

## Verified in practice

**Spike date: 2026-09-06. Issue [#11](https://github.com/DeepanshuPratik/Regolith_Onboarding/issues/11).**

### Method and caveats — read this before trusting anything below

**Environment.** Host session: sway 1.9 (Regolith) on Wayland. Test compositor: **a nested `gnome-shell --nested --wayland --wayland-display=wayland-spike`, GNOME Shell 46.0 / libmutter 46.2**, started under its own `dbus-run-session`. Toolkit: GTK **3.24.41**, Vala/C clients.

Two throwaway clients were built (in a scratch dir, not in `src/`, and not committed):

- **`spike`** — Vala/GTK3. Opens a plain `Gtk.Window`, prints every key press/release with keyval, name and modifier state, prints `focus-in`/`focus-out`, and takes/drops `Gdk.Seat.grab()` on command from a control FIFO. Run under `WAYLAND_DEBUG=1` so every Wayland request and event is on the record.
- **`obs`/`inhibobs`** — C/GTK3. Same window, but binds `zwp_keyboard_shortcuts_inhibit_manager_v1` itself off its own `wl_registry`, creates the inhibitor by hand and **installs a listener for `active`/`inactive`** — i.e. it sees exactly the feedback GTK3 throws away (§5). It never calls `Gdk.Seat.grab()`, so there is no `already_inhibited` collision.

Key injection was done with `ydotool` (uinput, kernel level) into the host sway session while the nested shell's window held sway focus; the nested compositor was the consumer. Verification was by three independent channels: the client's own key log, the `WAYLAND_DEBUG` wire trace, and `grim` screenshots of the nested compositor.

**Caveats, stated plainly:**

1. **A nested `gnome-shell` is not a real GNOME session.** It is a client of sway with a `MetaBackendX11Nested` backend, no `gnome-session`, no systemd user scope, and its own private D-Bus. Consent-dialog and PermissionStore behaviour especially could differ on real hardware. Everything below is labelled with a confidence level; anything marked **medium** should be re-confirmed on a real GNOME session before being designed against.
2. **KDE/KWin was not tested at all.** `kwin_wayland` is not installed on this machine. Per the decision recorded when this spike was scheduled, KDE is **untested**, not "assumed to match". Every finding below is Mutter-only.
3. **Mutter's `restore-shortcuts` escape hatch (`Super+Escape`) could not be tested**, because Regolith's own sway config binds `$mod+Escape` to the lock screen (`set_from_resource $wm.binding.lock wm.binding.lock Escape`), so the host compositor swallows the combination before the nested one ever sees it. Attempting it locked the host session. **Untested — do not assume.**
4. Another agent was injecting uinput events into the same host session during part of this run. Stray keystrokes appear in some traces. Every finding below is supported by at least one measurement free of that contamination, and the contaminated observations are not load-bearing.
5. The nested shell auto-locked once on idle mid-run; the affected measurement was re-taken after a restart.

---

### Q1. Does a keyboard-only grab actually inhibit Mutter's own shortcuts — and does the `KEYBOARD` vs `KEYBOARD | POINTER` distinction really matter?

**Answer: yes to both. The exact-equality capability check in §5 is real and is the whole ballgame. Confidence: HIGH.**

**(a) The capability check, on the wire.** Same process, same window, seconds apart:

```
[ 32.218] >>> GRAB(KEYBOARD|POINTER) requesting
[ 32.219] <<< GRAB(KEYBOARD|POINTER) returned SUCCESS          <- no protocol traffic at all

[ 36.328] >>> GRAB(KEYBOARD) requesting
  -> zwp_keyboard_shortcuts_inhibit_manager_v1@19.inhibit_shortcuts(
       new id zwp_keyboard_shortcuts_inhibitor_v1@37, wl_surface@30, wl_seat@21)
[ 36.328] <<< GRAB(KEYBOARD) returned SUCCESS
```

`Gdk.SeatCapabilities.KEYBOARD | POINTER` emits **no** `inhibit_shortcuts` request. `Gdk.SeatCapabilities.KEYBOARD` alone emits it. This is exactly the `capabilities == GDK_SEAT_CAPABILITY_KEYBOARD` branch at `gdkdevice-wayland.c:5174` quoted in §5, observed firing. **The judgment call recorded in [#8](https://github.com/DeepanshuPratik/Regolith_Onboarding/issues/8) — "grabs become keyboard-only (drop `| POINTER`)" — is load-bearing and correct.** With `| POINTER` the app gets nothing on Wayland.

Also confirmed: mutter 46.2 advertises the global, and GTK3 binds it unconditionally at client startup whether or not a grab ever happens —
`wl_registry@2.global(22, "zwp_keyboard_shortcuts_inhibit_manager_v1", 1)` followed immediately by `wl_registry@2.bind(...)`.

**(b) Mutter shortcuts actually stop firing.** Control vs test, same app, same key (`Alt+F2` = gnome-shell's `panel-run-dialog`), verified by screenshot each time:

| State | App's key log | Compositor |
|---|---|---|
| No grab | `Alt_L` only; `F2` never arrives | "Run a Command" dialog opens |
| `KEYBOARD` grab, consent allowed | `Alt_L`, then `F2 state=ALT` | nothing happens |

```
[ 39.374] KEY-PRESS #1 keyval=0xffe9 name=Alt_L  state=-      hw=64
[ 39.824] KEY-PRESS #2 keyval=0xffbf name=F2     state=ALT|   hw=68
```

Same result for `Ctrl+Alt+Right` (`switch-to-workspace-right`): delivered to the app as `Control_L`, `Alt_L`, `Right state=CTRL|ALT|`.

**(c) Bare Super is genuinely not carved out — confirmed empirically**, which is the single most surprising claim in §2:

| State | App's key log |
|---|---|
| No grab | Super never arrives (Mutter's `process_overlay_key` eats it) |
| `KEYBOARD` grab | `KEY-PRESS keyval=0xffeb name=Super_L`, then `KEY-RELEASE Super_L`, and the Activities overview does **not** open |

Note the asymmetry visible in the "no grab" rows above: **an un-inhibited Mutter still delivers the bare modifier press to the client and only swallows the combination.** An observer that keys off "did I see `Alt_L`?" will produce false positives. Only the full combination is evidence.

### Q2. The consent dialog: does it appear, what does it say, is it remembered?

**Answer: it appears; the exact text is below; it is remembered across runs *only if the window's `app_id` resolves to an installed `.desktop` file*. Confidence: HIGH for appearance and text; MEDIUM for the persistence rule (nested-session PermissionStore).**

Mutter/gnome-shell 46 shows a modal dialog, immediately on the `inhibit_shortcuts` request, reading verbatim:

> **Allow inhibiting shortcuts**
> The app *spike* wants to inhibit shortcuts
> You can restore shortcuts by pressing &lt;Super&gt;Escape.
> \[ **Deny** ] \[ **Allow** ]

`Allow` is the default/focused button. The app name is taken from the window's `app_id` (GTK3 sets it from `g_get_prgname()`; the wire shows `xdg_toplevel.set_app_id("spike")`).

**The dialog steals keyboard focus.** The app logs `FOCUS-OUT` the instant the grab is issued and does not get it back until the user answers. So there is a window — unbounded, it is a human — during which a "successfully grabbed" app receives nothing at all.

**Persistence.** Two distinct behaviours, and the difference is the `.desktop` file:

- **No matching desktop file:** the dialog reappears on **every run** of the same binary. No PermissionStore entry is written; `~/.local/share/flatpak/db/gnome` was never created. The nested shell logged `GDBus.Error:org.freedesktop.portal.Error.NotFound: No entry for shortcuts-inhibitor` on each lookup.
- **With `~/.local/share/applications/spike.desktop` installed** (matching `app_id=spike`): answering **Allow** writes a PermissionStore entry, and the **next run grabs silently with no dialog at all**. The entry is visible in the db:

  ```
  $ strings ~/.local/share/flatpak/db/gnome
  GVariant main shortcuts-inhibitor  spike.desktop  GRANTED  (va{sas})apps
  spike.desktop  shortcuts-inhibitor
  ```
  Table `gnome`, id `shortcuts-inhibitor`, app `spike.desktop` → `GRANTED`. Exactly the mechanism §2 described from source.

  Amusing corroboration of the matching rule: a second test binary named `obs` was silently matched to `com.obsproject.Studio.desktop` and inherited **OBS Studio's** permission row. **App-id matching is by name and it is sloppy** — pick a specific `app_id`.

**A `Deny` was not observed to persist** (dialog reappeared on the next run) — but that was measured on a binary without a desktop file, so it does not isolate the two variables. **Could not determine** whether Deny persists for an app that does have a desktop file.

**Design consequence:** the shipped app must install a `.desktop` file whose name matches the `app_id` it sets, or the user is prompted every single launch.

### Q3 (D15, the key question). After dropping the grab, letting another app take focus, and re-grabbing — does the re-grab land?

**Answer: NO. The re-grab does not land while another window holds keyboard focus, and the app cannot get focus back on its own. Confidence: HIGH.**

Full sequence, from the trace (`foot` used as the focus-stealing app; `ydotool`'s replay is equivalent for this purpose since what matters is that a spawned window takes focus):

```
[174.481] >>> UNGRAB
  -> zwp_keyboard_shortcuts_inhibitor_v1@37.destroy()
[176.489] >>> SPAWN foot
[176.543] FOCUS-OUT                                  <- foot takes keyboard focus
[180.162] STATE has_toplevel_focus=false is_active=false

[181.168] >>> GRAB(KEYBOARD) requesting              <- re-grab, while unfocused
  -> zwp_keyboard_shortcuts_inhibit_manager_v1@19.inhibit_shortcuts(
       new id zwp_keyboard_shortcuts_inhibitor_v1@39, wl_surface@30, wl_seat@21)
[181.168] <<< GRAB(KEYBOARD) returned SUCCESS
[181.168] FOCUS-OUT
[181.168] FOCUS-IN                                   <- SYNTHETIC. See below.
[183.327] STATE has_toplevel_focus=true is_active=true   <- A LIE.

[189.895] >>> PRESENT present_with_time(0)
  -> xdg_activation_v1@20.get_activation_token(new id xdg_activation_token_v1@37)
  -> xdg_activation_token_v1@37.set_serial(110, wl_seat@21)
  -> xdg_activation_token_v1@37.commit()
     xdg_activation_token_v1@37.done("43a123eb-...-641b7567c208_TIME0")
  -> xdg_activation_v1@20.activate("43a123eb-...", wl_surface@30)
                                                     <- Mutter ignores it. foot keeps focus.

[195.074] inject Alt+F2
                                                     <- app receives NOTHING
```

and the screenshot at that moment shows **`foot` still focused and Mutter's "Run a Command" dialog open**. The compositor acted on the shortcut; the app that believed it held a grab saw nothing.

Four separate findings fall out of this, all of them things #14 has to handle:

1. **The inhibitor is created successfully while unfocused, and is simply inert.** Mutter accepts `inhibit_shortcuts` from an unfocused surface without complaint; it just never consults it, because the check is against the *currently focused* window (§7). No error, no event.
2. **`gtk_window_present_with_time()` does not work on Mutter.** GTK3 does the right thing on the wire — it takes an `xdg_activation_v1` token and calls `activate` — and **Mutter refuses it**. (The token is minted with a stale serial, `set_serial(110, ...)`, and the `_TIME0` suffix reflects `GDK_CURRENT_TIME`; Mutter's activation policy requires a recent, focus-backed serial.) Both `present_with_time(GDK_CURRENT_TIME)` and a monotonic-ms timestamp were tried. **There is no programmatic way for this app to take focus back on GNOME.** The "visible click-to-continue fallback" in the [#8](https://github.com/DeepanshuPratik/Regolith_Onboarding/issues/8) judgment calls is not a nicety — it is the *only* recovery path.
3. **GTK3's focus state is actively misleading after a Wayland seat grab.** `Gdk.Seat.grab()` makes GDK synthesise a `FOCUS-OUT`/`FOCUS-IN` pair and flips `has_toplevel_focus` and `is_active` to `true` — *while another client demonstrably holds the compositor's keyboard focus*. **`has_toplevel_focus` / `is-active` / `focus-in-event` must not be used as the "am I armed?" signal.** The only trustworthy signal is *arriving key events*.
4. **A second `grab()` without an intervening `ungrab()` sends nothing at all.** At step 6 above, the grab returned `SUCCESS` with **zero** protocol traffic — GTK3's `gdk_wayland_window_get_inhibitor()` early-return (§5) means the inhibitor is only re-requested if the previous one was destroyed. A "just re-grab periodically" retry loop is a no-op unless each retry is `ungrab()` *then* `grab()`.

**The good news — the recovery path, once focus genuinely returns:**

```
[305.588] ===== kill foot =====
[306.161] FOCUS-IN                                   <- real focus return
[310.873] KEY-PRESS #12 Alt_L  state=-
[311.324] KEY-PRESS #13 F2     state=ALT|            <- inhibition is live again
```

The inhibitor created back at step 3 (while unfocused, apparently uselessly) **becomes effective again the instant the surface regains keyboard focus, with no new grab, no new request and no new consent dialog.** So the object is durable; only its effect is focus-gated.

**And the loop works perfectly as long as focus never leaves.** Rapid `ungrab` → `grab` → `ungrab` → `grab` with the app focused throughout: each `ungrab` destroys the inhibitor, each `grab` creates a fresh one, no dialog, and `Alt+F2` is still delivered to the app afterwards. **D15's "hold the grab → release only for dispatch → re-take it" is sound *provided the dispatch does not move focus*. It is broken whenever the dispatch spawns or raises a window.**

### Q4. If the re-grab does not land, what does the app observe — an error, or silence?

**Answer: silence. Total silence, at both the GDK level and the raw protocol level. Confidence: HIGH.**

The GTK3 client sees: `Gdk.GrabStatus.SUCCESS`, a synthetic `FOCUS-IN`, `has_toplevel_focus == true`, and then no key events. Nothing distinguishes that from "armed and the user simply hasn't typed yet."

The hand-rolled observer — which *does* listen for `active`/`inactive`, i.e. sees strictly more than GTK3 can — confirms there is nothing to hear:

```
[ 23.684] EVENT >>> inhibitor.ACTIVE        <- fires once, right after the user clicks Allow
[ 23.685] FOCUS-IN
[ 28.398] KEY-PRESS Alt_L ; [ 28.848] KEY-PRESS F2 state=0x8

[ 32.475] >>> SPAWN foot
[ 32.543] FOCUS-OUT                         <- inhibition is now dead
                                            <- NO `inactive` event. Silence.
[ 36.662] >>> present_with_time(0)          <- refused, silently
[ 39.764] FOCUS-IN                          <- foot killed, inhibition is live again
                                            <- NO second `active` event. Silence.
[ 44.311] KEY-PRESS Alt_L ; [ 44.761] KEY-PRESS F2 state=0x8
```

This matches the protocol text in §1 exactly, and settles one of the open items from the source pass: **Mutter emits `active` exactly once, when consent is granted, and emits nothing thereafter on focus loss or focus return.** Manually binding the protocol to get the events buys you precisely one signal — "consent was granted" — and nothing at all about the arming state over time. It does not solve the D15 problem.

**Conclusion for #14: the timeout-and-visible-fallback is mandatory, not defensive.** There is no event, no error and no queryable state. The only observable is "keys are/aren't arriving."

### Q5. Does `Gdk.Seat.grab()` return SUCCESS even when the inhibitor was refused? Is the return value trustworthy?

**Answer: it returns SUCCESS unconditionally. The return value is worthless as a signal. Confidence: HIGH.**

`Gdk.GrabStatus.SUCCESS` was returned in every single case measured, including:

- when the request was refused by the user (**Deny**);
- when the surface was unfocused and the inhibitor therefore inert;
- when GTK3 sent no protocol request at all (the double-grab early-return);
- when the capability was `KEYBOARD | POINTER` and no inhibitor was ever requested.

This is unavoidable by construction: §5's source shows the Wayland backend does `gdk_wayland_window_inhibit_shortcuts(...); return GDK_GRAB_SUCCESS;` — the return happens synchronously, before the request has even been flushed, let alone answered by a human clicking a dialog button.

**What Deny looks like from inside the app** (observer with an `active`/`inactive` listener, app focused, 5 s of waiting after the click):

```
[  4.253] >>> REQUEST inhibit_shortcuts
[  4.253] <<< REQUEST sent
          ... user presses Deny ...
[ 20.486] FOCUS-IN                          <- dialog closed, focus back
          ... 5 s of nothing: no `active`, no `inactive`, no protocol error ...
[ 25.597] KEY-PRESS keyval=0xffe9 name=Alt_L state=0x0
[ 26.053] FOCUS-OUT                         <- Mutter opened Run a Command; shortcuts live
```

**A denied inhibitor is indistinguishable from a granted one, from the return value alone. Even with the `active`/`inactive` listener GTK3 lacks, Deny produces no event — only the *absence* of `active`, which is only detectable with a timeout.**

---

### What this means for [#14](https://github.com/DeepanshuPratik/Regolith_Onboarding/issues/14) (the keyboard-only-grab observer)

**Verdict: safe to build as designed, with four constraints that the design must absorb.**

Solid:
- Keyboard-only `Gdk.Seat.grab()` really does inhibit Mutter's shortcuts, bare Super included, with no manual protocol code.
- The hold/release/re-take loop is correct and cheap when focus stays put.
- Recovery is automatic and free once focus genuinely returns.

Constraints, each backed by evidence above:
1. **`| POINTER` must not be present.** It silently disables the whole mechanism.
2. **Never trust `GrabStatus`, `has_toplevel_focus`, `is-active`, or `focus-in-event` as the armed signal** — all four lie after a seat grab. The only ground truth is an arriving key event. Arm-detection has to be "I saw the expected keys", with a timeout.
3. **A re-grab must be `ungrab()` then `grab()`.** Bare repeated `grab()` calls send nothing.
4. **The app cannot take focus back.** `present_with_time()`/`xdg_activation` is refused by Mutter. Any dispatch that moves focus ends the practice step until the *user* clicks back — so the "click to continue" fallback is the primary recovery path, not an edge case. Prefer dispatch actions that do not steal focus where the workflow allows it.

Plus one packaging requirement: **ship a `.desktop` file whose basename matches the `app_id`**, or GNOME prompts for consent on every launch.

**Still unverified — do not design against these:**
- **All of KDE/KWin.** Untested (no `kwin_wayland` on the test machine). KWin has no consent dialog per §3, so Q2 is likely moot there, but Q3/Q4 are wide open and KWin's focus and activation policies differ.
- **Mutter's `Super+Escape` restore-shortcuts escape hatch** — blocked by the host's own `$mod+Escape` lock binding. The consent dialog advertises it to the user, so **assume a user can silently disarm the app at any moment**; this is just another instance of constraint 2.
- **Real (non-nested) GNOME.** Consent-dialog and PermissionStore behaviour in particular.
- Whether a **Deny** is persisted for an app that does have a desktop file.
