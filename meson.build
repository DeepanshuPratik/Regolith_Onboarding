project('regolith_onboarding', 'vala', version: '1.12.1')

# 2. Import Modules
gnome = import('gnome')  

project_sources = []
subdir('src')
subdir('src/components')
subdir('src/flow')
subdir('src/intro')
subdir('src/parser')

project_resources = gnome.compile_resources(
  'project-resources',
  'data/app.gresource.xml',
  source_dir: 'data'
)

add_project_arguments(['--pkg', 'GtkLayerShell-0.1'], language: 'vala')
add_project_arguments(['--pkg', 'posix'], language: 'vala')

layer_shell_dep = meson.get_compiler('c').find_library('gtk-layer-shell', required: true)
regolith_onboarding_deps = [dependency('gio-unix-2.0')]
regolith_onboarding_deps += dependency('json-glib-1.0')
regolith_onboarding_deps += dependency('atk')
regolith_onboarding_deps += dependency('cairo-gobject')
regolith_onboarding_deps += dependency('gdk-3.0')
regolith_onboarding_deps += dependency('gdk-pixbuf-2.0')
regolith_onboarding_deps += dependency('gio-2.0')
regolith_onboarding_deps += dependency('glib-2.0')
regolith_onboarding_deps += dependency('gobject-2.0')
regolith_onboarding_deps += dependency('gtk+-3.0')
regolith_onboarding_deps += dependency('pango')
regolith_onboarding_deps += dependency('x11')
regolith_onboarding_deps += dependency('libhandy-1')

regolith_onboarding_deps += layer_shell_dep
regolith_onboarding_deps += dependency('gee-0.8')
regolith_onboarding_deps += dependency('json-glib-1.0')

executable(
  'regolith_onboarding',
  project_sources, 
  project_resources,
  dependencies: regolith_onboarding_deps,
  install: true
)