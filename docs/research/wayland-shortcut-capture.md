# Capturing and Re-triggering Desktop-Owned Keyboard Shortcuts on Linux (2026)

**Research date: 2026-09-06.** All load-bearing claims below are cited to a primary source URL. Where a claim could only be established by inference, or where sources disagreed, it is flagged inline as such rather than asserted.

## Summary

There is **no portable, unprivileged mechanism for a normal Linux desktop application to observe that the user pressed a shortcut the desktop/compositor already owns.** The one interface that looks like it should do this — `org.freedesktop.portal.GlobalShortcuts` — does the opposite of what its name suggests to most readers: it lets an app *register a new abstract action* which the *user* then assigns a key combo to via a system dialog. It provides no way to name an existing combo (e.g. GNOME's own `Super+Enter`) and be told when it fires. Observation of an *already-bound, compositor-owned* shortcut is therefore: **impossible for a third-party app on GNOME/Mutter Wayland** (the only real route is an in-process GNOME Shell extension); **apparently possible on KDE Plasma** via `kglobalacceld`'s broadcast D-Bus signals; **not available via portal on wlroots/sway** (the tracking issue is still open); and **possible-but-exclusive on native X11**, where `XGrabKey` succeeds only if no other client — including the window manager — already holds that grab. Synthesis is the easier half of the problem: `/dev/uinput` (ydotool) injects at the kernel evdev level and is indistinguishable from real hardware to every compositor, at the cost of root/`input`-group privileges; the `RemoteDesktop` portal plus libei/EIS works on both GNOME and KDE but re-prompts the user for consent by default.

## Summary table

| Environment | Observe a compositor-owned shortcut | Synthesize a keypress the desktop acts on |
|---|---|---|
| **GNOME/Mutter (Wayland)** | **No** for a normal app. `GlobalShortcuts` only registers *new* actions; `org.gnome.Shell.GrabAccelerator` is allowlisted to three trusted senders; `Eval` requires unsafe-mode. **Conditional:** a GNOME Shell **extension** (in-process) can, via `Meta.Display` / `Main.wm.addKeybinding`. Static binding *config* is readable from GSettings, but that is not event observation. | **Conditional.** `RemoteDesktop` portal + EIS (mutter has libei support); requires a user consent dialog, re-prompted per session unless `persist_mode` is requested. Or `/dev/uinput` with elevated privileges. |
| **KDE Plasma 6 (Wayland)** | **Conditional — likely Yes.** `kglobalacceld` emits `globalShortcutPressed` as a plain broadcast D-Bus signal on `/component/<name>`; any session client can match on it. Enumeration via `org.kde.KGlobalAccel.allComponents()` / `allActionsForComponent()` is ungated. *(Signal-observability is inferred from source + default session-bus semantics, not from an explicit KDE statement — see §5.)* | **Conditional.** `RemoteDesktop` portal + kwin's EIS backend (consent dialog applies). Also `org.kde.kglobalaccel.Component.invokeShortcut()` can trigger the *action* directly without synthesizing a key at all. Or `/dev/uinput`. |
| **wlroots / sway** | **No** via portal — `xdg-desktop-portal-wlr` issue #240 (GlobalShortcuts) is still **open**. *(A compositor-config route — binding a key in the sway config to a command that notifies your app — is the obvious workaround but was not verified against a primary source in this pass; see §1 open questions.)* | **Yes** via `/dev/uinput` (ydotool), with privilege setup. Portal `RemoteDesktop` availability on `xdg-desktop-portal-wlr` was not verified in this pass. |
| **X11 (native session)** | **Conditional — Yes, but exclusive.** `XGrabKey` grabs any combo globally, but returns `BadAccess` if another client (typically the WM) already grabbed it. So you can grab a *free* combo, not silently observe one the WM owns. | **Yes** in practice (XTEST is the conventional route), and `/dev/uinput` always works. *(XTEST specifically was not fetched as a primary source in this pass — flagged.)* |
| **XWayland** | **No** for compositor-owned or native-Wayland-client shortcuts. X11 grabs are scoped to Xwayland's own event routing and cannot redirect the Wayland compositor's focus. | Injection into XWayland reaches X11 clients only; it does not drive compositor-level bindings. Use `/dev/uinput` or the portal instead. |

---

## 1. `org.freedesktop.portal.GlobalShortcuts`

**Primary source:** <https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.GlobalShortcuts.html> (documents interface version 2).

### The critical nuance: register-new, not observe-existing — resolved

The spec is unambiguous. `BindShortcuts` takes `IN shortcuts a(sa{sv})`, where each entry is an **application-chosen shortcut ID string** plus a vardict containing only two documented fields:

- `description (s)` — "User-readable text describing what the shortcut does."
- `preferred_trigger (s)` — "The preferred shortcut trigger, defined as described by the shortcuts XDG specification. Optional."

There is **no field for passing an existing key combination the app wishes to intercept**, and no method to enumerate the compositor's own bindings and attach to one. `preferred_trigger` is a *hint* only: the spec states that `BindShortcuts` "will typically result in the portal presenting a dialog showing the shortcuts and allowing users to configure the shortcuts." The human, via a system UI, decides the actual combo.

Reinforcing this, the `BindShortcuts` response returns `trigger_description (s)` — "User-readable text describing how to trigger the shortcut for the client to render." The app gets a *display string*, not a structured keysym/keycode it could reuse programmatically.

`ListShortcuts` is likewise scoped to the caller: "If BindShortcuts was called for session_handle, all active shortcuts for session_handle are returned. Otherwise returns the shortcuts that were successfully bound in a previous session by this application." It is not a system-wide keybinding query API.

`ConfigureShortcuts` (added in v2) — "Request showing a configuration UI so the user is able to configure all shortcuts of this session" — is again a human-mediated surface, not a query.

**Conclusion:** GlobalShortcuts is a *"declare an abstract action, let the user assign the key"* mechanism. An app cannot silently subscribe to a combo the compositor already owns. Even if the user were shown the dialog and tried to assign `Super+Enter` to the app's action, a compositor-reserved combo can simply be refused — though note the spec does not enumerate reserved combos or specify refusal semantics, so that behavior is backend-specific and **unresolved at the spec level**.

### Signals

`Activated` and `Deactivated` carry `(session_handle o, shortcut_id s, timestamp t, options a{sv})`. `shortcut_id` is documented as "the application-provided ID for the notification" — i.e. it echoes back the ID the app itself invented, which independently confirms the app-defined-ID model.

### Backend implementation status

| Backend | Status | Evidence |
|---|---|---|
| `xdg-desktop-portal-kde` | **Implemented**, MR !80 "Implementation of the GlobalShortcuts portal" merged **2022-11-30**, milestone **Plasma 5.27**. Description: "It uses systemsettings and KGlobalAccel to implement it." | <https://invent.kde.org/plasma/xdg-desktop-portal-kde/-/merge_requests/80> |
| `xdg-desktop-portal-gnome` | **Implemented**, ~**GNOME 48** (March 2025). "This Week in GNOME" #189 (2025-02-28) states the desktop portal "now supports the Global Shortcuts interface," letting applications "register desktop-wide shortcuts," with users able to "edit and revoke them through the system settings." Built on gnome-shell's `Grab`/`UngrabAccelerator` D-Bus API. | <https://discourse.gnome.org/t/189-global-shortcuts/27375>; MR at <https://gitlab.gnome.org/GNOME/xdg-desktop-portal-gnome/-/merge_requests/208> |
| `xdg-desktop-portal-wlr` | **Not implemented.** Tracking issue #240 "Global shortcut portal support," opened 2022-09-30, confirmed **still OPEN** at fetch time (2026-09-06). The opener notes it is "not possible with current sway/wlroots" and would require real wlroots/sway changes. | <https://github.com/emersion/xdg-desktop-portal-wlr/issues/240> |
| `xdg-desktop-portal-hyprland` | **Implemented.** The backend's portal descriptor lists `org.freedesktop.impl.portal.GlobalShortcuts` among its interfaces, with `UseIn=wlroots;Hyprland;sway;Wayfire;river;`. Later releases show ongoing bugfixes in `CGlobalShortcutsPortal::onListShortcuts`, indicating a live implementation. | <https://github.com/hyprwm/xdg-desktop-portal-hyprland/blob/master/hyprland.portal> |

### Open questions / flagged items (§1)

- The GNOME MR !208 merge state read **ambiguously** on a direct page fetch (once appearing still open), conflicting with the dated official GNOME blog post. The blog post is treated as authoritative here, but the discrepancy is noted.
- The "added in v0.2.0 / paired with Hyprland 0.24.1" detail for the Hyprland backend came from search-engine synthesis, **not** a directly quoted page.
- **Not researched in this pass:** the sway-config route (binding a key in the sway config to a command that notifies your app over an IPC/socket). This is the obvious practical workaround on a sway-based desktop like Regolith and is worth a follow-up research pass; it is *not* asserted here as verified.
- **Regolith implication:** which portal backend Regolith ships determines availability entirely. On a wlroots/sway variant, GlobalShortcuts is unavailable today; on a GNOME-based variant it is available (but only in the register-new-action sense described above).

---

## 2. `org.freedesktop.portal.RemoteDesktop` + libei/EIS

**Primary source:** <https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.RemoteDesktop.html> (interface version 2).

### Synthesizing a specific key

Two methods, differing in *which identity space* names the key:

```
NotifyKeyboardKeycode (IN session_handle o, IN options a{sv}, IN keycode i, IN state u)
NotifyKeyboardKeysym  (IN session_handle o, IN options a{sv}, IN keysym  i, IN state u)
```

Both are documented as "May only be called if KEYBOARD access was provided after starting the session," with `state` being `0: Released`, `1: Pressed`. `keycode` is "Keyboard code that was pressed or released" (Linux evdev keycode space — physical/positional, layout-dependent); `keysym` is "Keyboard symbol that was pressed or released" (X11/XKB keysym space — symbolic, layout-independent). There is **no modifiers argument**: modifier keys are sent as their own press/release events, so triggering `Super+Enter` means four calls (Super down, Enter down, Enter up, Super up).

### EIS is the recommended path

The spec states: "There are two ways to send input events to the remote desktop session: EIS (recommended): Call ConnectToEIS() after starting the session… D-Bus Notify methods… Once an EIS connection is established, the Notify* D-Bus methods must not be used."

```
ConnectToEIS (IN session_handle o, IN options a{sv}, OUT fd h)
```

"The returned handle can be passed to `ei_setup_backend_fd()` for a libei sender context… This method may only be called once per session… Once an EIS connection is established, input events must be sent exclusively via the EIS connection."

### Consent model — this is the practical blocker

- `Start()`: "This will typically result in the portal presenting a dialog letting the user select what to share, including devices and optionally screen content…" — **a consent dialog is the default.**
- Persistence is opt-in via `SelectDevices()` options: `persist_mode (u)`, **default 0**, where `0` = "Do not persist (default)", `1` = "Permissions persist as long as the application is running", `2` = "Permissions persist until explicitly revoked."
- `restore_token (s)`: "The token to restore a previous session. If the stored session cannot be restored, this value is ignored and the user will be prompted normally… **The restore token is invalidated after using it once.** To restore the same session again, use the new restore token sent in response to starting this session."

**Answer:** it re-prompts every session by default. With `persist_mode` set, an app can avoid re-prompting, but must persist and rotate a single-use token on every `Start()`, and the backend may still re-prompt (e.g. when stored permissions are withdrawn). Nothing guarantees a silent, indefinite promptless reconnect.

### Compositor support

- **mutter:** MR !2628, "Add EI support with InputCapture and RemoteDesktop" — explicitly the *third* attempt, superseding closed MR !1436 because "the libei API had changed significantly." mutter's `meson.build` requires `libei >= 1.3.901`. <https://gitlab.gnome.org/GNOME/mutter/-/merge_requests/2628>, <https://gitlab.gnome.org/GNOME/mutter/-/merge_requests/1436>
- **kwin:** MR !5496 "Add a libeis backend 🍦" (David Redondo, created 2024-03-21): adds "a libeis backend to KWin that enables clients to send emulated input events… clients are expected to go through the RemoteDesktop portal," with "a separate eis context per portal request… to restrict the device types available to clients according to what was approved via the portal." <https://invent.kde.org/plasma/kwin/-/merge_requests/5496>
- **kwin owns the EIS server; the KDE portal is a pass-through.** `xdg-desktop-portal-kde`'s `remotedesktop.cpp` implements `ConnectToEIS` by making a D-Bus call to kwin (`"connectToEIS"`) and returning kwin's fd. <https://github.com/KDE/xdg-desktop-portal-kde/blob/master/src/remotedesktop.cpp>
- Plasma changelogs for 6.5.0 and 6.6.0 show only *incremental fixes* to an already-existing kwin `eis` plugin ("Plugins/eis: Correct a typo," "Eis: Add support for touch canceling"), indicating a mature feature well before 2025. <https://kde.org/announcements/changelogs/plasma/6/6.4.5-6.5.0/>

### libei/EIS mechanics

Canonical repo is **<https://gitlab.freedesktop.org/libinput/libei>** (note: `github.com/libinput/libei` does not exist). Per the README (read via the Chromium mirror, <https://chromium.googlesource.com/external/gitlab.freedesktop.org/libinput/libei/+/refs/heads/main/README.md>): "In the Wayland stack, the EIS server component is part of the compositor, the EI client component is part of the Wayland client." Since 0.3 a context is in exactly one mode — **sender** ("can emulate events on these devices" — the synthesis case) or **receiver** ("receives events from those" — the basis of the separate `InputCapture` portal). "A libei context may only be in one mode."

### Open questions / flagged items (§2)

- **Exact merge dates and target releases for mutter !2628 and kwin !5496 could not be confirmed** — gitlab.gnome.org returned 406 and invent.kde.org returned 403 to direct fetches, and the rendered pages did not surface merge badges. Landing timeframes (mutter/libei ≈ GNOME 45, Sept 2023; kwin/libeis before Plasma 6.5) are corroborated only *indirectly*, via build-dependency pins and changelog maturity.
- **How the portal's `NotifyKeyboardKeysym` is translated into an EIS/keymap event on the compositor side was not confirmed from any primary source.** The libei README says "the server informs the client about the keymap it expects and it is up to the client to provide the correct keyboard events," implying a keymap+keycode wire protocol, but no protocol field name was directly quoted. If exact keysym fidelity matters to an implementation, verify this empirically.

---

## 3. `ydotool` (`/dev/uinput`)

**Primary source:** <https://raw.githubusercontent.com/ReimuNotMoe/ydotool/master/README.md>; repo metadata via the GitHub API.

### Requirements

- README, verbatim: "`ydotoold` (daemon) program requires access to `/dev/uinput`. **This usually requires root permissions.**"
- Architecture rationale, verbatim: "ydotool works differently from xdotool. xdotool sends X events directly to X server, while ydotool uses the uinput framework of Linux kernel to emulate an input device."
- Why the daemon exists, verbatim: "When ydotool runs and creates a virtual input device, it will take some time for your graphical environment (X11/Wayland) to recognize and enable the virtual input device. (Usually done by udev) … a persistent background service, ydotoold, is made to hold a persistent virtual device, and accept input from ydotool. **Since v1.0.0, the use of ydotoold is mandatory.**"
- **The README does not document a udev rule or `input`-group setup.** That guidance lives only in issues: the commonly recommended rule is `KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"`, and <https://github.com/ReimuNotMoe/ydotool/issues/210> reports it *failing to apply* on Arch until `/dev/uinput` is chmod'd or `uinput` is modprobe'd manually.
- A second, distinct permissions gotcha: <https://github.com/ReimuNotMoe/ydotool/issues/73> — `ydotoold` is commonly run setuid root / setgid input, and creates `/tmp/.ydotool_socket` at mode `600`, which then blocks other `input`-group users from using the client.
- <https://github.com/ReimuNotMoe/ydotool/issues/285> (Ubuntu 24.04 GNOME/Wayland) shows a user following udev rule + group + systemd service and still hitting "ydotoold backend unavailable" — **unresolved in the visible thread.** Setup remains fragile and distro-dependent in practice.
- **Licensing note (may matter for Regolith):** the project moved to **AGPLv3**.

### Distro packaging

- **Arch:** official `extra` repo, `ydotool 1.0.4-2` — <https://archlinux.org/packages/extra/x86_64/ydotool/> (graduated from AUR; `ydotool-git` still in AUR).
- **Debian:** official, `1.0.4-3`, present Bullseye through Sid — <https://packages.debian.org/sid/utils/ydotool>. Notably, **Debian ships the udev rule** (`usr/lib/udev/rules.d/80-uinput.rules`) in the package, so the manual setup burden is reduced there.
- **Fedora:** official, `1.0.4-8.fc44` in Rawhide/F45/F44 — <https://packages.fedoraproject.org/pkgs/ydotool/ydotool/>.

### Are uinput events genuinely hardware-equivalent to a Wayland compositor?

- Kernel doc, verbatim (<https://www.kernel.org/doc/html/latest/input/uinput.html>): "uinput is a kernel module that makes it possible to emulate input devices from userspace. By writing to /dev/uinput … a process can create a virtual input device with specific capabilities. Once this virtual device is created, the process can send events through it, that will be delivered to userspace and in-kernel consumers." The kernel doc confirms the mechanism but is **silent on indistinguishability**.
- The explicit confirmation comes from Peter Hutterer (libinput/X.Org input maintainer), <http://who-t.blogspot.com/2016/05/the-difference-between-uinput-and-evdev.html>: "Any event written to the /dev/uinput node will re-appear in that /dev/input/eventN node and a device created through uinput looks just pretty much like a physical device to a process. **You can detect uinput-created virtual devices, but usually a process doesn't need to care so all the common userspace (libinput, Xorg) doesn't bother.**"

**Verdict: Yes** — since sway/wlroots, mutter and kwin all consume input via libinput, and libinput reads structurally identical evdev nodes, uinput-injected keypresses reach the compositor as genuine input and *will* fire compositor-owned bindings. **Flagged inference:** this last step is architectural reasoning (kernel doc + Hutterer + libinput's role), not a direct wlroots/sway/mutter statement — no compositor-side primary source saying so in plain terms was found.

### Maintenance status (flagged)

`ReimuNotMoe/ydotool` is not archived and shows commits into late 2025, but the **last tagged release is still v1.0.4 (2023-01-30)** — nearly three years without a release — and the README's "2024 Roadmap" promising a rewrite has not visibly materialized. The README's only status statement is the vague "This project is now being maintained thanks to all the people that are supporting this project!" Treat long-term maintenance as **uncertain**.

---

## 4. GNOME-specific configuration and observation surface

### 4.1 Reading keybinding config from GSettings — Yes (same-user)

- **dconf(7)** (<https://manpages.ubuntu.com/manpages/focal/man7/dconf.7.html>): "All preferences are stored in a single large binary file… Reads are performed by direct access (via mmap) to the on-disk database… dconf reads typically involve zero system calls." The only access control the man page describes is **write-side locking** (mandatory settings), not read restriction. Corroborated by <https://wiki.gnome.org/Projects/dconf> and <https://wiki.gnome.org/Projects/dconf/SystemAdministrators> (the latter frames admin lockdown purely as write-prevention).
- **Flagged gap:** no *GNOME-hosted* page states "any process can read any app's settings" in plain language. The most explicit statement found is from the **Ubuntu Security Team wiki** (a distro doc, not GNOME upstream) — <https://wiki.ubuntu.com/SecurityTeam/Specifications/ApplicationConfinement>: "Any application that can access the database files can read and modify settings for other applications… Even simply obtaining read access to other application's settings may expose sensitive information." That document exists to justify layering AppArmor mediation *on top of* dconf, which is itself evidence dconf has no such mediation.
- **Refinement:** `~/.config/dconf/user` is typically mode `664` inside a `700` directory. So it is readable by every process running **as that user** (i.e. every app in the session), not by other Unix users. For a same-user app, `gsettings get` / `dconf read` on `org.gnome.desktop.wm.keybindings` and `org.gnome.settings-daemon.plugins.media-keys` works.
- **This is static configuration, not event observation.** You can learn *what* `Super+Enter` is bound to; you cannot learn *when* it fires.

### 4.2 Custom keybindings relocatable schema — confirmed

From <https://raw.githubusercontent.com/GNOME/gnome-settings-daemon/master/data/org.gnome.settings-daemon.plugins.media-keys.gschema.xml.in> (the custom-keybinding schema is a second `<schema>` block in the *same* file, not a separate one):

```xml
<schema id="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding">
  <key name="name" type="s"><default>''</default></key>
  <key name="binding" type="s"><default>''</default></key>
  <key name="command" type="s"><default>''</default></key>
  <key name="enable-in-lockscreen" type="b"><default>false</default></key>
</schema>
```

The `<schema>` element has **no `path` attribute**, which per <https://docs.gtk.org/gio/class.Settings.html> is precisely the definition of a relocatable schema. The parent schema holds a `custom-keybindings` key of type `as` (array of dconf paths), instantiated under `/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/customN/`. Confirmed in GNOME Settings' own source: `g_settings_new_with_path (item->schema, path)` in <https://raw.githubusercontent.com/GNOME/gnome-control-center/main/panels/keyboard/cc-keyboard-item.c>, with the base path in <https://raw.githubusercontent.com/GNOME/gnome-control-center/main/panels/keyboard/keyboard-shortcuts.c>.

### 4.3 `org.gnome.Shell` D-Bus: `Eval` *and* `GrabAccelerator` are both locked down

**`Eval`** — the exact lockdown commit was found: `7298ee23e91b756c7009b4d7687dfd8673856f8b`, Florian Müllner, **17 June 2021**, "shellDBus: Use MetaContext:unsafe-mode to restrict Eval()" (<https://mail.gnome.org/archives/commits-list/2021-September/msg01051.html>). Commit message: "The Eval() method is unarguably the most sensitive D-Bus method we expose, since it allows running arbitrary code in the compositor… guard it by the new MetaContext:unsafe-mode property instead of the setting." The diff replaces `global.settings.get_boolean('development-tools')` with `global.context.unsafe_mode`. Part of MR !1970 (<https://gitlab.gnome.org/GNOME/gnome-shell/-/merge_requests/1970>). Still in force today — <https://raw.githubusercontent.com/GNOME/gnome-shell/main/js/ui/shellDBus.js>:

```js
async EvalAsync(params, invocation) {
    if (!global.context.unsafe_mode) {
        invocation.return_value(new GLib.Variant('(bs)', [false, '']));
        return;
    }
```

**Version correction:** the widely-repeated "since GNOME 3.34" figure appears to be **wrong**. The commit is dated June 2021, and GNOME 41 was released 22 September 2021 (<https://mail.gnome.org/archives/devel-announce-list/2021-September/msg00002.html>), so **GNOME 41** is the correct answer. *Flagged: this is inferred from commit date vs. release date; no NEWS/release-notes line stating it verbatim was found.* (An earlier, weaker `development-tools` GSettings gate existed before this — which may be the origin of the 3.34 folklore.)

**`GrabAccelerator` — the more important finding.** `org.gnome.Shell.xml` (<https://raw.githubusercontent.com/GNOME/gnome-shell/main/data/dbus-interfaces/org.gnome.Shell.xml>) exposes `GrabAccelerator`, `GrabAccelerators`, `UngrabAccelerator`, and a signal `AcceleratorActivated(u action, a{sv} parameters)` — which looks like a third-party observation route. It is not. The live implementation in `shellDBus.js` gates it behind a fixed sender allowlist:

```js
this._senderChecker = new DBusSenderChecker([
    'org.gnome.Settings',
    'org.gnome.SettingsDaemon.MediaKeys',
    'org.freedesktop.impl.portal.desktop.gnome',
]);
...
async GrabAcceleratorAsync(params, invocation) {
    try {
        await this._senderChecker.checkInvocation(invocation);
    } catch (e) { invocation.return_gerror(e); return; }
```

(`DBusSenderChecker` at <https://raw.githubusercontent.com/GNOME/gnome-shell/main/js/misc/util.js>.) A third-party app **cannot call `GrabAccelerator` at all**. And even for the three permitted callers, it only registers a *new* accelerator for the caller and reports *that* accelerator's activation — it is not an enumeration or eavesdropping facility. This is exactly the machinery the GNOME GlobalShortcuts portal sits on top of, which is consistent with §1's conclusion.

### 4.4 Is a GNOME Shell extension the only realistic route? — Yes

The research **supports this conclusion, and strengthens it.** In-process, extensions have unrestricted access:

- `Main.wm.addKeybinding(name, settings, flags, modes, handler)` wraps `global.display.add_keybinding(...)` — <https://raw.githubusercontent.com/GNOME/gnome-shell/main/js/ui/windowManager.js>
- The official Mutter API reference (<https://mutter.gnome.org/meta/class.Display.html>) documents `add_keybinding`, `grab_accelerator`, and the signals `accelerator-activated`, `accelerator-deactivated`, `modifiers-accelerator-activated`.
- gnome-shell's own D-Bus service consumes precisely this in-process signal (`global.display.connect('accelerator-activated', …)` in `shellDBus.js`) — i.e. **this in-process signal is the only place activation actually surfaces**; every external route to it is gated.

**Verdict: on GNOME Wayland, a Shell extension is the only supported way to observe a compositor-owned keybinding firing in real time.** This is confirmed against live gnome-shell and mutter source, not inferred from documentation summaries.

---

## 5. KDE Plasma `kglobalaccel`

### 5.1 Enumeration — Yes, ungated

From the interface XML at <https://raw.githubusercontent.com/KDE/kglobalaccel/master/src/org.kde.KGlobalAccel.xml>:

```xml
<interface name="org.kde.KGlobalAccel">
  <method name="allComponents"><arg type="ao" direction="out"/></method>
  <method name="allMainComponents"><arg type="aas" direction="out"/></method>
  <method name="allActionsForComponent">
    <arg type="aas" direction="out"/><arg name="actionId" type="as" direction="in"/>
  </method>
  <method name="getComponent"><arg type="o" direction="out"/>
    <arg name="componentUnique" type="s" direction="in"/></method>
  <method name="shortcutKeys">…</method>
  <method name="defaultShortcutKeys">…</method>
  <method name="setShortcutKeys">…</method>
  <signal name="yourShortcutsChanged">…</signal>
</interface>
```

Any session-bus client can call `allComponents()` (returns object paths, one per component), then `allActionsForComponent()` for the action IDs, and `shortcutKeys`/`defaultShortcutKeys` for the actual key sequences. Nothing in the XML gates these to particular callers. This is a genuinely richer introspection surface than anything GNOME offers.

### 5.2 Observing activations of shortcuts owned by other components — apparently Yes

The daemon lives in a **separate repo** from the framework: <https://github.com/KDE/kglobalacceld>. Each component is exposed at its own D-Bus object path. From <https://raw.githubusercontent.com/KDE/kglobalaccel/master/src/org.kde.kglobalaccel.Component.xml>:

```xml
<interface name="org.kde.kglobalaccel.Component">
  <signal name="globalShortcutPressed">
    <arg name="componentUnique" type="s" direction="out"/>
    <arg name="actionUnique" type="s" direction="out"/>
    <arg name="timestamp" type="x" direction="out"/>
  </signal>
  <signal name="globalShortcutRepeated">…</signal>
  <signal name="globalShortcutReleased">…</signal>
  <method name="shortcutNames">…</method>
  <method name="allShortcutInfos">…</method>
  <method name="invokeShortcut">…</method>
</interface>
```

And the emission site, <https://raw.githubusercontent.com/KDE/kglobalacceld/master/src/component.cpp>:

```cpp
QDBusObjectPath Component::dbusPath() const {
    return QDBusObjectPath(QLatin1String("/component/") + dbusPath);
}

void Component::emitGlobalShortcutEvent(const GlobalShortcut &shortcut, ShortcutKeyState state) {
    case ShortcutKeyState::Pressed:
        Q_EMIT globalShortcutPressed(shortcut.context()->component()->uniqueName(),
                                     shortcut.uniqueName(), timestamp);
}
```

This is a plain `Q_EMIT` on a `QDBusAbstractAdaptor`-backed object at a well-known path — a **broadcast signal with no destination**, which the session bus delivers to every client with a matching signal-match rule. Nothing in the adaptor, the XML, or the registration restricts *reception* to the owning component.

A related feature that is **not** a per-subscriber ACL: `kglobalacceld`'s README (<https://raw.githubusercontent.com/KDE/kglobalacceld/master/README.md>) documents an allowlist mode — "When allowlist mode is enabled, only shortcuts explicitly listed in the allowlist are permitted to trigger" — configured in `~/.config/kglobalaccelrc`. This gates whether a shortcut fires *at all* (kiosk/lock-screen use), not who may observe the signal.

**Also note `invokeShortcut()`** on the Component interface: on KDE, an app can trigger another component's action *directly* without synthesizing any keypress. For the "re-trigger the shortcut" half of the problem, this is a cleaner path than input injection.

**Verdict: a third-party app can subscribe to `globalShortcutPressed` for components it does not own**, by matching on the `org.kde.kglobalaccel.Component` interface at `/component/<uniqueName>`.

**Flagged:** this conclusion rests on (a) the XML showing a plain broadcast signal with no access-control annotation and (b) daemon source showing an undestined `Q_EMIT`, combined with default session-bus semantics. **No D-Bus policy file** (`/usr/share/dbus-1/session.d/*.conf`) was located or checked for kglobalaccel that might further restrict receive/eavesdrop rights; permissive default behavior is inferred from the *absence* of such a file in the two repos inspected, not from a fetched policy. **Verify empirically with `dbus-monitor` before depending on it.**

---

## 6. X11 `XGrabKey` and XWayland

### 6.1 Native X11 — works, but grabs are exclusive

Man page: <https://xorg.freedesktop.org/archive/current/doc/man/man3/XGrabKey.3.xhtml>

```c
int XGrabKey(Display *display, int keycode, unsigned int modifiers,
             Window grab_window, Bool owner_events,
             int pointer_mode, int keyboard_mode);
```

It "establishes a passive grab on the keyboard." A `KeyPress` is reported to the grabbing client when the keyboard isn't already grabbed, the key is pressed with exactly the specified modifiers, `grab_window` relates appropriately to the focus window, and **no conflicting passive grab exists on an intervening ancestor window**. `keyboard_mode` accepts `GrabModeSync` (freezes delivery until `XAllowEvents()`) or `GrabModeAsync`.

**The load-bearing nuance is in the error list:** `BadAccess` — "A client attempted to grab a key/button combination already grabbed by another client."

So on native X11 an app *can* grab arbitrary global combos — this is a server-side X protocol feature, independent of the window manager — but it **cannot silently observe a combo the WM already grabbed**; that attempt fails with `BadAccess`. Grabbing is *taking ownership*, not eavesdropping. (Passive observation without stealing the binding would need something like the XRecord extension; **that was not researched in this pass** and is flagged as an open avenue.)

### 6.2 XWayland — architecturally cannot do it

The authoritative statement is in the `xwayland-keyboard-grab-unstable-v1` protocol spec (read via <https://wayland.app/protocols/xwayland-keyboard-grab-unstable-v1> and confirmed against the Chromium mirror of the upstream XML; gitlab.freedesktop.org itself was behind an anti-bot wall):

> "The core Wayland protocol does not have a notion of an active keyboard grab."

> "When running in Xwayland, X11 applications may acquire an active grab inside Xwayland but that cannot be translated to the Wayland compositor who may set the input focus to some other surface. In doing so, it breaks the X11 client assumption that all key events are reported to the grabbing client."

This directly confirms the scope limitation: an XWayland client's `XGrabKey`/`XGrabKeyboard` has effect only **within the Xwayland X server's own event routing**. It cannot force the Wayland compositor to route input to that surface, and shortcuts consumed at the compositor level never reach Xwayland at all.

The workaround protocol explicitly disclaims guarantees: it "does not guarantee that the grab is ever satisfied, and does not require the compositor to send an error if the grab cannot ever be satisfied," and "does not guarantee that the compositor will honor this request." It also requires that "Compositors are required to restrict access to this application specific protocol to Xwayland alone." It remains an **unstable** (`zwp_`) protocol.

Real-world corroboration:

- <https://gitlab.gnome.org/GNOME/mutter/-/issues/3842> ("xwayland-allow-grabs option not working"): an X11 app doing `XGrabKeyboard()` on the root window — "demo app should 'catch' all key presses and show them under Wayland just like under X11, but it works under X11 only" — even with `xwayland-allow-grabs=true`. **No maintainer response was visible; the report is unresolved.**
- <https://bugzilla.gnome.org/show_bug.cgi?id=783342> (original mutter RFC for keyboard-grab / shortcut-inhibitor support) shows the feature was deliberately built with compositor-side gatekeeping (confirmation dialogs, allowlisting) *because* ungated XWayland grabs are treated as a security/UX risk.

### Open questions / flagged items (§6)

- **Point (b) — that XWayland cannot intercept events destined for native Wayland clients — is an inference** from "the core Wayland protocol does not have a notion of an active keyboard grab" plus Xwayland's status as one ordinary Wayland client. No source states this specific negative case verbatim.
- A **third-party** engineering note (<https://github.com/aaddrick/claude-desktop-debian/blob/main/docs/learnings/wayland-global-shortcuts-portal.md>, **not** a primary source) claims "mutter (GNOME ≥ 49) no longer honours XWayland-side global key grabs, so the grab only fires when the window already has focus." **This could not be corroborated against any official mutter changelog, release note, or GitLab issue.** Treat the "GNOME 49 regression" detail as unverified.
- **X11 input synthesis (XTEST / `XTestFakeKeyEvent`) was not fetched as a primary source in this pass.** It is the conventional mechanism and is expected to work on native X11, but it is not verified here, and injecting via XTEST under XWayland would by the same architecture only reach X11 clients — not compositor-level bindings.

---

## Bottom line

**If you need to detect that the user pressed an existing system shortcut:**

- **GNOME Wayland: write a GNOME Shell extension.** There is no supported alternative. `GlobalShortcuts` registers new actions only; `org.gnome.Shell.GrabAccelerator` is allowlisted to three trusted services; `Eval` needs unsafe-mode. Inside the shell process, `Meta.Display`'s `accelerator-activated` signal and `Main.wm.addKeybinding` are unrestricted. Accept the cost: extensions break across GNOME releases and need review for distribution.
- **KDE Plasma: connect to `org.kde.kglobalaccel.Component`'s `globalShortcutPressed` broadcast signal** at `/component/<name>`, after enumerating components via `org.kde.KGlobalAccel.allComponents()`. This appears to work for shortcuts you do not own — **verify with `dbus-monitor` first**, since the conclusion is source-derived rather than documented.
- **sway/wlroots (i.e. Regolith's likely target): no portal route today** (xdg-desktop-portal-wlr #240 is open). The pragmatic answer is almost certainly to go through the compositor's own config — bind the key in the sway/i3 config to a command that notifies your process — which sidesteps the whole problem by making the *compositor* the one that tells you. **This route was not verified in this research pass and should be the first follow-up.**
- **X11: `XGrabKey` works, but it takes the binding rather than observing it.** If the WM already owns the combo you care about, you get `BadAccess`. Consider XRecord for true passive observation (unverified here).
- **XWayland: don't.** X11 grabs are scoped to Xwayland's internal event routing by design, per the `xwayland-keyboard-grab` protocol's own text. Anything that "works" here is accidental and version-fragile.

**If you need to re-trigger / synthesize the keypress:**

- **`/dev/uinput` (ydotool) is the only mechanism that works identically everywhere**, because it operates below the compositor at the kernel evdev level — libinput and X.Org do not distinguish virtual devices from real ones. The price is privilege: root or `input`-group plus a udev rule, a mandatory `ydotoold` daemon, a socket-permission gotcha, real-world setup failures reported on stock Ubuntu/GNOME, AGPLv3 licensing, and a project with no tagged release since January 2023.
- **The `RemoteDesktop` portal + libei/EIS is the sanctioned route** on GNOME and KDE (both compositors implement the EIS server side), using `NotifyKeyboardKeysym` / `NotifyKeyboardKeycode`, or preferably a libei sender context via `ConnectToEIS`. Remember there is no modifiers argument — `Super+Enter` is four separate press/release events. The blocker is consent: a dialog on every `Start()` by default, and even with `persist_mode` the restore token is single-use and rotates each session.
- **On KDE specifically, prefer `org.kde.kglobalaccel.Component.invokeShortcut()`** — trigger the action directly and skip input synthesis entirely. No consent dialog, no privileges, no key-event round trip.

**The one-sentence version:** synthesis is a solved problem with a privilege-or-consent tax; *observation* of a shortcut the desktop already owns is not solved on Wayland by design, and the portal that appears to solve it (`GlobalShortcuts`) explicitly does not — it lets you ask the user for a *new* binding, never to listen in on an existing one.
