# filename: data/meson.build
#
# The launcher entry, and the icon that goes with it.

desktop_file = app_id + '.desktop'

install_data(
  desktop_file,
  install_dir: get_option('datadir') / 'applications',
)

# The icon follows the branding rather than being a fixed asset of this
# repository: identity here is compiled in and chosen by -Dbranding_dir, and a
# launcher entry carrying another distro's logo would be a bug rather than a
# default. Installed under APP_ID so the desktop file's Icon= key resolves
# without either name having to be repeated anywhere else.
#
# The contract on a branding directory is that logo.png is a square PNG. A
# non-square one still installs; it just looks wrong at launcher sizes.
branding_logo = branding_dir / 'logo.png'
if fs.exists(branding_logo)
  install_data(
    branding_logo,
    install_dir: get_option('datadir') / 'icons' / 'hicolor' / '512x512' / 'apps',
    rename: app_id + '.png',
  )
else
  warning('no logo.png in ' + branding_dir + ' — the launcher entry will fall back to a generic icon')
endif
