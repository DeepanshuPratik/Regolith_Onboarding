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
     * Finding workflows on disk, in both layouts.
     *
     * The marketplace gives each workflow its own folder, so that its images
     * cannot collide with another author's:
     *
     *     workflows/gnome/navigation/navigation.json
     *     workflows/gnome/navigation/assets/keys.png
     *
     * Discovery used to read only the `*.json` sitting directly in the desktop
     * directory, so nothing in that shape was ever found. The flat layout is
     * what every existing install and the bundled branding use, so both have to
     * work — and a workflow's images resolve against **its own** directory,
     * which is the whole reason the folder exists.
     */

    private string locator_tmpdir () {
        try {
            return DirUtils.make_tmp ("onboarding-locator-XXXXXX");
        } catch (Error e) {
            Test.message ("cannot make a temp dir: %s", e.message);
            Test.fail ();
            return "/tmp";
        }
    }

    private void write_workflow (string dir, string filename, string name, string? image) {
        DirUtils.create_with_parents (dir, 0755);
        var img = image == null ? "" : ", \"image\": \"%s\"".printf (image);
        var json = """{"version": 1, "desktop": "gnome", "workflows": [
            {"name": "%s", "description": "d", "steps": [
              {"key_id": "<> a", "heading": "h", "description": "d"%s}]}]}"""
            .printf (name, img);
        try {
            FileUtils.set_contents (Path.build_filename (dir, filename), json);
        } catch (Error e) {
            Test.message ("cannot write %s: %s", filename, e.message);
            Test.fail ();
        }
    }

    private Gee.ArrayList<Workflow> load_from (string desktop_dir) {
        var found = new Gee.ArrayList<Workflow> ();
        // load_dir is internal rather than private precisely so this can drive
        // it: the alternative is a test that needs a real desktop and an XDG
        // directory to find out which layouts are discoverable.
        new WorkflowLocator ().load_dir (found, desktop_dir);
        return found;
    }

    /** The layout every existing install has. */
    private void test_locator_finds_flat_workflows () {
        var root = locator_tmpdir ();
        write_workflow (root, "01-navigation.json", "Flat", null);

        var found = load_from (root);
        check_int ("one workflow", found.size, 1);
        if (found.size == 1) check_str ("name", found[0].name, "Flat");
    }

    /** The layout the marketplace uses. */
    private void test_locator_finds_workflow_in_its_own_folder () {
        var root = locator_tmpdir ();
        write_workflow (Path.build_filename (root, "navigation"), "navigation.json", "Nested", null);

        var found = load_from (root);
        check_int ("one workflow", found.size, 1);
        if (found.size == 1) check_str ("name", found[0].name, "Nested");
    }

    /**
     * The point of the folder: a workflow's images resolve against the folder
     * that holds it, so two authors can both ship `assets/keys.png`.
     */
    private void test_locator_images_resolve_beside_their_own_json () {
        var root = locator_tmpdir ();
        var dir = Path.build_filename (root, "navigation");
        write_workflow (dir, "navigation.json", "Nested", "assets/keys.png");

        var found = load_from (root);
        check_int ("one workflow", found.size, 1);
        if (found.size == 1) {
            check_str ("image base is the workflow's own folder", found[0].base_dir, dir);
        }
    }

    /** Both shapes at once, which is what an install that grew over time looks like. */
    private void test_locator_finds_both_layouts_together () {
        var root = locator_tmpdir ();
        write_workflow (root, "01-flat.json", "Flat", null);
        write_workflow (Path.build_filename (root, "nested"), "nested.json", "Nested", null);

        var found = load_from (root);
        check_int ("both", found.size, 2);
    }

    /**
     * One level, not arbitrary depth. A user's stray directory under their
     * workflows folder is not a workflow, and walking into everything invites
     * scanning whatever someone happens to have put there.
     */
    private void test_locator_does_not_recurse_further () {
        var root = locator_tmpdir ();
        write_workflow (Path.build_filename (root, "too/deep"), "deep.json", "TooDeep", null);

        check_int ("nothing found two levels down", load_from (root).size, 0);
    }

    /**
     * A folder holding several JSONs is somebody's own directory, not a
     * marketplace workflow — the marketplace allows exactly one. Reading all of
     * them would be a surprising amount of guessing.
     */
    private void test_locator_ignores_a_folder_with_several_jsons () {
        var root = locator_tmpdir ();
        var dir = Path.build_filename (root, "scratch");
        write_workflow (dir, "one.json", "One", null);
        write_workflow (dir, "two.json", "Two", null);

        check_int ("skipped", load_from (root).size, 0);
    }

    /** Order is stable, so an NN- prefix still controls how the catalogue lists. */
    private void test_locator_order_is_stable () {
        var root = locator_tmpdir ();
        write_workflow (root, "02-second.json", "Second", null);
        write_workflow (root, "01-first.json", "First", null);
        write_workflow (Path.build_filename (root, "03-third"), "03-third.json", "Third", null);

        var found = load_from (root);
        check_int ("three", found.size, 3);
        if (found.size == 3) {
            check_str ("first",  found[0].name, "First");
            check_str ("second", found[1].name, "Second");
            check_str ("third",  found[2].name, "Third");
        }
    }

    /**
     * The reported bug, as a test: Ubuntu's XDG_CURRENT_DESKTOP normalises to
     * ["ubuntu", "gnome", "default"], and this repo bundles no "ubuntu"
     * workflows directory — only the fallthrough to "gnome" makes an Ubuntu
     * GNOME session load anything but the fallback set.
     */
    private void test_locator_falls_through_to_first_existing_candidate () {
        var root = locator_tmpdir ();
        DirUtils.create_with_parents (Path.build_filename (root, "gnome"), 0755);

        var candidates = Desktop.build_candidates ("Ubuntu:GNOME");
        var chosen = WorkflowLocator.first_existing_candidate (root, candidates);

        check_str ("skips missing ubuntu/, lands on gnome/",
                   chosen, Path.build_filename (root, "gnome"));
    }

    /** When nothing on the candidate list exists under root, there is nothing to fall back to. */
    private void test_locator_no_existing_candidate_is_null () {
        var root = locator_tmpdir ();
        var chosen = WorkflowLocator.first_existing_candidate (root, {"ubuntu", "gnome", "default"});
        check_str ("no directory matches", chosen, null);
    }

    public void register_locator () {
        Test.add_func ("/locator/flat", test_locator_finds_flat_workflows);
        Test.add_func ("/locator/own-folder", test_locator_finds_workflow_in_its_own_folder);
        Test.add_func ("/locator/images-beside-json", test_locator_images_resolve_beside_their_own_json);
        Test.add_func ("/locator/both-layouts", test_locator_finds_both_layouts_together);
        Test.add_func ("/locator/one-level-only", test_locator_does_not_recurse_further);
        Test.add_func ("/locator/folder-with-several-jsons", test_locator_ignores_a_folder_with_several_jsons);
        Test.add_func ("/locator/stable-order", test_locator_order_is_stable);
        Test.add_func ("/locator/falls-through-to-first-existing-candidate", test_locator_falls_through_to_first_existing_candidate);
        Test.add_func ("/locator/no-existing-candidate-is-null", test_locator_no_existing_candidate_is_null);
    }
}
