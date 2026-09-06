# filename: src/platforms/meson.build
project_sources += files(
  'platform.vala',
  'registry.vala'
)

# One line per desktop, alongside the one line in registry.vala's all().
subdir('sway')
subdir('wayland')
subdir('x11')
