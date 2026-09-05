project('linux-onboarding', 'vala', version: '1.12.1')

# 2. Import Modules
gnome = import('gnome')  

project_sources = []
subdir('src')
subdir('src/branding')
subdir('src/capture')
subdir('src/components')
subdir('src/flow')
subdir('src/intro')
subdir('src/platform')
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