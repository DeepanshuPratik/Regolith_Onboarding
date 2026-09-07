# filename: tests/meson.build
#
# The test cases. Same shape as src/*/meson.build: a directory lists its own
# files and the top-level meson.build builds the target from them.
#
# The target has to be declared at the root rather than here — meson derives a
# Vala target's generated C paths from the target's own directory, so a target
# in tests/ cannot compile ../src/*.vala. The code under test is therefore
# listed alongside the target, in the top-level meson.build.
#
# Adding a suite: drop test_<area>.vala here, add it below, add the .vala it
# exercises to `test_sources` at the root, and call its register_ function from
# main () in harness.vala.
test_sources += files(
  'harness.vala',
  'test_asset_fit.vala',
  'test_desktop.vala',
  'test_kde_bindings.vala',
  'test_key_spec.vala',
  'test_locator.vala',
  'test_key_synthesizer.vala',
  'test_key_tables.vala',
  'test_palette.vala',
  'test_sanitiser.vala',
  'test_state.vala',
  'test_sway_vars.vala',
  'test_ydotool.vala',
  'test_version.vala'
)
