project('regolith_onboarding', 'vala', version: '1.12.1')

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

executable(
  'regolith_onboarding',
  sources: ['src/main.vala', 'src/intro/intro_window.vala'],
  dependencies: regolith_onboarding_deps,
  install: true
)
