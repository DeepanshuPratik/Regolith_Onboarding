project('linux-onboarding', 'vala', version: '1.12.1')

# 2. Import Modules
gnome = import('gnome')  

project_sources = []
subdir('src')
subdir('src/components')
subdir('src/flow')
subdir('src/intro')
subdir('src/platform')
subdir('src/spike')  # PHASE 0 SPIKE

project_resources = gnome.compile_resources(
  'project-resources',
  'data/app.gresource.xml',
  source_dir: 'data'
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
app_deps += dependency('webkit2gtk-4.1')  # PHASE 0 SPIKE

app_deps += layer_shell_dep
app_deps += dependency('gee-0.8')
app_deps += dependency('json-glib-1.0')

executable(
  'linux-onboarding',
  project_sources, 
  project_resources,
  dependencies: app_deps,
  install: true
)