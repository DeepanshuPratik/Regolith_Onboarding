project('regolith_onboarding', 'vala', version: '1.12.1')
add_project_arguments(['--pkg', 'GtkLayerShell-0.1'], language: 'vala')
add_project_arguments(['--pkg', 'posix'], language: 'vala')

layer_shell_dep = meson.get_compiler('c').find_library('gtk-layer-shell', required: false)
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
  sources: ['src/main.vala', 'src/intro/introPage.vala','src/parser/configParser.vala','src/flow/flow_list.vala','src/parser/I3Ipc.vala','src/flow/flow_window.vala','src/components/buttons.vala','src/components/labels.vala','src/onboardingWindow.vala','src/components/common.vala','src/parser/jsonReader.vala'],
  dependencies: regolith_onboarding_deps,
  install: true
)
