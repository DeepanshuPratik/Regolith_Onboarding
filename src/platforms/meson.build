# filename: src/platforms/meson.build
project_sources += files(
  'platform.vala',
  'registry.vala'
)

# The mechanism shared by the desktops that have no window-manager IPC.
subdir('seatgrab')

# One line per desktop, alongside the one line in registry.vala's all().
subdir('gnome')
subdir('kde')
subdir('sway')
subdir('wayland')
subdir('x11')
