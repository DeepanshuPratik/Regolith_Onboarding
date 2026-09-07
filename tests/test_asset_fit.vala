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
     * Fitting a demo asset into the practice page's slot.
     *
     * The bug behind these: assets were shown at their natural size, the shipped
     * set runs from 500x346 to 1600x900, and so the page — and the window around
     * it — was a different size on every step of a workflow.
     */

    // The slot WorkFlowPage uses. Duplicated deliberately: if the page changes
    // its slot, these cases should be re-read rather than silently follow.
    private const int BOX_W = 340;
    private const int BOX_H = 230;

    private void check_fits (string label, int src_w, int src_h) {
        int w, h;
        AssetLoader.fit_size (src_w, src_h, BOX_W, BOX_H, out w, out h);
        check_bool (label + ": within the slot width",  w <= BOX_W, true);
        check_bool (label + ": within the slot height", h <= BOX_H, true);

        // Proportions kept, to within the rounding of one pixel.
        double src_ratio = (double) src_w / src_h;
        double out_ratio = (double) w / h;
        check_bool (label + ": keeps its proportions",
                    (src_ratio - out_ratio).abs () < 0.02, true);
    }

    /** Every asset the reference branding actually ships. */
    private void test_fit_shipped_assets () {
        check_fits ("floating.jpeg",      1600, 900);
        check_fits ("ilia.jpeg",           964, 788);
        check_fits ("Navigation.jpeg",     745, 417);
        check_fits ("resize.jpeg",         694, 307);
        check_fits ("terminalSplit.gif",   500, 346);
        check_fits ("workspaces.jpeg",     653, 311);
    }

    /** A tall asset is bound by height, a wide one by width. */
    private void test_fit_picks_the_binding_edge () {
        int w, h;
        AssetLoader.fit_size (1600, 900, BOX_W, BOX_H, out w, out h);
        check_int ("wide asset fills the width", w, BOX_W);

        AssetLoader.fit_size (400, 1200, BOX_W, BOX_H, out w, out h);
        check_int ("tall asset fills the height", h, BOX_H);
    }

    /** Smaller than the slot is left alone rather than blown up. */
    private void test_fit_never_upscales () {
        int w, h;
        AssetLoader.fit_size (120, 80, BOX_W, BOX_H, out w, out h);
        check_int ("width unchanged",  w, 120);
        check_int ("height unchanged", h, 80);
    }

    /** A broken asset reports no size; the slot is still the slot. */
    private void test_fit_of_nothing () {
        int w, h;
        AssetLoader.fit_size (0, 0, BOX_W, BOX_H, out w, out h);
        check_int ("width",  w, BOX_W);
        check_int ("height", h, BOX_H);
    }

    public void register_asset_fit () {
        Test.add_func ("/asset-fit/shipped-assets", test_fit_shipped_assets);
        Test.add_func ("/asset-fit/binding-edge", test_fit_picks_the_binding_edge);
        Test.add_func ("/asset-fit/never-upscales", test_fit_never_upscales);
        Test.add_func ("/asset-fit/of-nothing", test_fit_of_nothing);
    }
}
