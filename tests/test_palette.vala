/****************************************************************************************
 * Copyright (c) 2023 Deepanshu Pratik <deepanshu.pratik@gmail.com>                     *
 *                                                                                      *
 * This program is free software; you can redistribute it and/or modify it under        *
 * the terms of the Apache License as published by the Free Software                    *
 * Foundation; either version 2 of the License, or (at your option) any later           *
 * version.                                                                             *
 *                                                                                      *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY      *
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A      *
 * PARTICULAR PURPOSE. See the Apache License for more details.                         *
 *                                                                                      *
 * You should have received a copy of the Apache License along with this program.       *
 *  If not, see <http://www.apache.org/licenses/>.                                      *
 ****************************************************************************************/

namespace linux_onboarding.Tests {

    /**
     * The per-desktop palette: reading a desktop's accent colour, and the two
     * stylesheets generated from it.
     *
     * Only the pure half is here — no GSettings, no screen, no CSS provider.
     * What that leaves is exactly what can go wrong quietly: a colour parsed out
     * of someone else's config file, and generated CSS that has to stay valid in
     * two different dialects (GTK's and the web's).
     */

    /** KDE writes its accent as decimal RGB triplets in kdeglobals. */
    private void test_palette_kde_accent () {
        check_str ("breeze blue",
                   Palette.kde_accent_in ("[General]\nAccentColor=61,174,233\n"),
                   "#3daee9");
        check_str ("spaces tolerated",
                   Palette.kde_accent_in ("[General]\nAccentColor= 255, 0, 0 \n"),
                   "#ff0000");
    }

    /** Anything that is not three numbers in range is not a colour. */
    private void test_palette_kde_accent_rejects_rubbish () {
        check_str ("no key",        Palette.kde_accent_in ("[General]\nWidgetStyle=Breeze\n"), null);
        check_str ("two fields",    Palette.kde_accent_in ("[General]\nAccentColor=61,174\n"), null);
        check_str ("out of range",  Palette.kde_accent_in ("[General]\nAccentColor=61,174,300\n"), null);
        check_str ("not numeric",   Palette.kde_accent_in ("[General]\nAccentColor=blue\n"), null);
        check_str ("empty file",    Palette.kde_accent_in (""), null);
    }

    /** A dark colour scheme is named, not flagged. */
    private void test_palette_kde_dark_detection () {
        check_bool ("BreezeDark", Palette.kde_prefers_dark_in ("[General]\nColorScheme=BreezeDark\n"), true);
        check_bool ("Breeze",     Palette.kde_prefers_dark_in ("[General]\nColorScheme=Breeze\n"), false);
        check_bool ("absent",     Palette.kde_prefers_dark_in ("[General]\n"), false);
    }

    /** GNOME names its accent; the hex behind the name is Adwaita's. */
    private void test_palette_gnome_accent_names () {
        check_str ("blue",    Palette.gnome_accent_hex ("blue"),   "#3584e4");
        check_str ("purple",  Palette.gnome_accent_hex ("purple"), "#9141ac");
        check_str ("unknown", Palette.gnome_accent_hex ("mauve"),  null);
    }

    /** Every desktop this build knows has an accent, whether or not it can be read. */
    private void test_palette_per_desktop_defaults () {
        check_bool ("regolith", Palette.is_hex_colour (Palette.default_accent_for ("regolith")), true);
        check_bool ("gnome",    Palette.is_hex_colour (Palette.default_accent_for ("gnome")),    true);
        check_bool ("kde",      Palette.is_hex_colour (Palette.default_accent_for ("kde")),      true);
        check_bool ("sway",     Palette.is_hex_colour (Palette.default_accent_for ("sway")),     true);
        check_bool ("unknown desktop still gets one",
                    Palette.is_hex_colour (Palette.default_accent_for ("something-else")), true);
    }

    /** Desktops are meant to look different from one another. */
    private void test_palette_desktops_differ () {
        check_bool ("gnome and kde differ",
                    Palette.default_accent_for ("gnome") == Palette.default_accent_for ("kde"),
                    false);
    }

    /** A colour a distro hand-wrote has to be checked before it reaches CSS. */
    private void test_palette_hex_validation () {
        check_bool ("#3daee9",  Palette.is_hex_colour ("#3daee9"), true);
        check_bool ("#ABC123",  Palette.is_hex_colour ("#ABC123"), true);
        check_bool ("no hash",  Palette.is_hex_colour ("3daee9"),  false);
        check_bool ("short",    Palette.is_hex_colour ("#3da"),    false);
        check_bool ("not hex",  Palette.is_hex_colour ("#zzzzzz"), false);
        check_bool ("injection",Palette.is_hex_colour ("#3daee9; } * { color: red"), false);
        check_bool ("empty",    Palette.is_hex_colour (""),        false);
    }

    /** The GTK half defines the names app.css and flow.css use. */
    private void test_palette_gtk_css () {
        var css = Palette.gtk_css_for ("#3daee9");
        check_bool ("defines the accent",
                    css.contains ("@define-color onboarding_accent #3daee9;"), true);
        check_bool ("defines a foreground for it",
                    css.contains ("@define-color onboarding_accent_fg"), true);
    }

    /** The web half is what app:///palette.css serves to the slides. */
    private void test_palette_web_css () {
        var dark = Palette.web_css_for ("#3daee9", true);
        check_bool ("custom property", dark.contains ("--desktop-accent: #3daee9;"), true);
        check_bool ("declares the scheme", dark.contains ("color-scheme: dark;"), true);

        var light = Palette.web_css_for ("#3daee9", false);
        check_bool ("light scheme", light.contains ("color-scheme: light;"), true);
    }

    /**
     * Both sheets are generated from the same colour, so a build cannot end up
     * with a GTK window in one accent and a slide deck in another.
     */
    private void test_palette_both_sheets_carry_one_colour () {
        var accent = "#ed5b00";
        check_bool ("gtk", Palette.gtk_css_for (accent).contains (accent), true);
        check_bool ("web", Palette.web_css_for (accent, true).contains (accent), true);
    }

    /**
     * The name says "a foreground that reads on it", so it has to. White was
     * hardcoded here, which fails outright on GNOME's yellow accent.
     */
    private void test_palette_foreground_contrast () {
        check_str ("dark accent takes white",  Palette.foreground_on ("#2f6fb5"), "#ffffff");
        check_str ("purple takes white",       Palette.foreground_on ("#9141ac"), "#ffffff");
        check_str ("gnome yellow takes black", Palette.foreground_on ("#c88800"), "#1a1a1a");
        check_str ("near-white takes black",   Palette.foreground_on ("#f5f5f5"), "#1a1a1a");
        check_str ("black takes white",        Palette.foreground_on ("#000000"), "#ffffff");
    }

    /** Anything unparseable falls back rather than reaching CSS half-formed. */
    private void test_palette_foreground_of_rubbish () {
        check_str ("not a colour", Palette.foreground_on ("wat"), "#ffffff");
    }

    /** The generated sheet carries the computed foreground, not a fixed one. */
    private void test_palette_gtk_css_foreground_follows_accent () {
        check_bool ("yellow gets a dark foreground",
                    Palette.gtk_css_for ("#c88800").contains ("@define-color onboarding_accent_fg #1a1a1a;"),
                    true);
    }

    public void register_palette () {
        Test.add_func ("/palette/foreground-contrast", test_palette_foreground_contrast);
        Test.add_func ("/palette/foreground-of-rubbish", test_palette_foreground_of_rubbish);
        Test.add_func ("/palette/gtk-css-foreground", test_palette_gtk_css_foreground_follows_accent);
        Test.add_func ("/palette/kde-accent", test_palette_kde_accent);
        Test.add_func ("/palette/kde-accent-rejects-rubbish", test_palette_kde_accent_rejects_rubbish);
        Test.add_func ("/palette/kde-dark", test_palette_kde_dark_detection);
        Test.add_func ("/palette/gnome-accent-names", test_palette_gnome_accent_names);
        Test.add_func ("/palette/per-desktop-defaults", test_palette_per_desktop_defaults);
        Test.add_func ("/palette/desktops-differ", test_palette_desktops_differ);
        Test.add_func ("/palette/hex-validation", test_palette_hex_validation);
        Test.add_func ("/palette/gtk-css", test_palette_gtk_css);
        Test.add_func ("/palette/web-css", test_palette_web_css);
        Test.add_func ("/palette/one-colour-two-sheets", test_palette_both_sheets_carry_one_colour);
    }
}
