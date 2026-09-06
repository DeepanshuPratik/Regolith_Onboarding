project('linux-onboarding', 'vala', version: '1.12.1')

# 2. Import Modules
gnome = import('gnome')
fs = import('fs')

# The application id. Deliberately reverse-DNS and deliberately not the binary
# basename: GNOME's lookup of an app_id against installed desktop files is
# loose enough that a spike binary named `obs` inherited OBS Studio's stored
# permissions, so a generic token is a real hazard here.
#
# GTK3 takes the Wayland app_id from the program name (verified on 3.24.41:
# xdg_toplevel.set_app_id carries g_get_prgname(), not the GApplication id), so
# src/main.vala sets the program name to this string, and data/ installs a
# desktop file named after it. All three have to agree.
app_id = 'org.linux.Onboarding'

# Nothing enforces that agreement at runtime — the compositor compares strings
# and simply finds nothing on a mismatch. The symptom is a consent dialog on
# every launch on a GNOME machine, which no build and no test here would catch,
# so the two halves are compared at configure time instead.
if not fs.read('src/Constants.vala').contains('APP_ID = "' + app_id + '"')
  error(
    'app_id mismatch: meson.build says \'' + app_id + '\' but src/Constants.vala ' +
    'does not declare APP_ID = "' + app_id + '". These must stay in step, along ' +
    'with data/' + app_id + '.desktop — see docs/DISTRO-GUIDE.md.',
  )
endif

project_sources = []
subdir('src')
subdir('src/branding')
subdir('src/flow')
subdir('src/keys')
subdir('src/platforms')
subdir('src/services')
subdir('src/session')
subdir('src/slides')
subdir('src/workflows')

project_resources = gnome.compile_resources(
  'project-resources',
  'data/app.gresource.xml',
  source_dir: 'data'
)

# A distro's branding is compiled in, selected by -Dbranding_dir. Meson has no
# glob, so the resource manifest is generated at configure time from whatever
# that directory contains.
branding_dir = get_option('branding_dir')
if not branding_dir.startswith('/')
  branding_dir = meson.project_source_root() / branding_dir
endif
message('branding_dir: ' + branding_dir)

branding_xml = configure_file(
  output: 'branding.gresource.xml',
  command: [find_program('python3'), meson.project_source_root() / 'data/gen-branding-gresource.py', branding_dir],
  capture: true,
)

branding_resources = gnome.compile_resources(
  'branding-resources',
  branding_xml,
  source_dir: branding_dir,
)

# After branding_dir, because the launcher icon comes out of it.
subdir('data')

add_project_arguments(['--pkg', 'GtkLayerShell-0.1'], language: 'vala')
add_project_arguments(['--pkg', 'posix'], language: 'vala')

layer_shell_dep = meson.get_compiler('c').find_library('gtk-layer-shell', required: true)
app_deps = [dependency('gio-unix-2.0')]
app_deps += dependency('json-glib-1.0')
app_deps += dependency('atk')
app_deps += dependency('cairo-gobject')
app_deps += dependency('gdk-3.0')
app_deps += dependency('gdk-pixbuf-2.0')
app_deps += dependency('gio-2.0')
app_deps += dependency('glib-2.0')
app_deps += dependency('gobject-2.0')
app_deps += dependency('gtk+-3.0')
app_deps += dependency('pango')
app_deps += dependency('x11')
app_deps += dependency('libhandy-1')
app_deps += dependency('webkit2gtk-4.1')

app_deps += layer_shell_dep
app_deps += dependency('gee-0.8')
app_deps += dependency('json-glib-1.0')

executable(
  'linux-onboarding',
  project_sources,
  project_resources,
  branding_resources,
  dependencies: app_deps,
  install: true
)

# ---- tests ----------------------------------------------------------------
#
# `meson test -C build`. The cases live in tests/; the code they exercise is
# compiled straight into the test binary rather than linked from a library.
# The app builds one executable out of `project_sources`, which includes
# main.vala, so a test binary — which needs its own main () — cannot link that
# as it stands. Extracting a static library would mean splitting
# `project_sources` in every src/*/meson.build and re-pointing the executable
# at it: a change across the whole build for the sake of four files. Naming the
# files costs one line each and leaves every existing meson.build untouched.
# Promote this to a library if the covered surface ever outgrows a short list.
#
# Declared here, after add_project_arguments(), because meson derives a Vala
# target's generated C paths from the target's own directory — a target under
# tests/ cannot compile ../src/*.vala.
test_sources = []
subdir('tests')

# Pure, session-free code under test: no display, no compositor, no main loop.
# Observers, placers and dispatchers are deliberately absent — they need a live
# session, and a test that needs one is a test nobody runs.
test_sources += files(
  'src/Constants.vala',
  'src/branding/onboarding_state.vala',
  'src/branding/version.vala',
  'src/keys/key_spec.vala',
  'src/keys/key_synthesizer.vala',
  'src/keys/key_tables.vala',
  'src/keys/sanitise.vala',
  # KdeResolver's parsing: pure string work, and the only part of the KDE
  # platform that can be held to account without a Plasma machine.
  'src/platforms/kde/resolver.vala',
  'src/services/binding_resolver.vala',
  # KeySynthesizer.command_for asks Desktop which session it is in.
  'src/session/desktop.vala'
)

# gdk-3.0 for the modifier masks in key_tables.vala; gtk+-3.0 because the
# project-wide `--pkg GtkLayerShell-0.1` pulls in a vapi declared against Gtk.
test_deps = [
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gdk-3.0'),
  dependency('gtk+-3.0')
]

unit_tests = executable(
  'unit-tests',
  test_sources,
  dependencies: test_deps,
  install: false
)

# TAP so meson names each failing case instead of reporting one pass/fail for
# the lot, which is what makes the suite worth adding cases to.
test('unit', unit_tests, args: ['--tap'], protocol: 'tap')
