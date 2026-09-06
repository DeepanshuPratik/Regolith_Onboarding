# Generating workflow art with Gemini

Every workflow step can carry a picture, and the welcome page and slides are HTML
that can carry anything WebKit renders. This is how to generate that art with an
image model without producing a set that looks assembled from three different
apps.

Read the constraints first. They are not style advice — they are what the code
actually does with your file, and a prompt that ignores them produces an asset
that is technically fine and looks wrong in the app.

## What the app does with your file

There are **two** slots, and they have different rules.

| | Practice-step image | Welcome page and slides |
|---|---|---|
| Rendered by | GdkPixbuf, in a fixed slot | WebKit, as a real web page |
| Slot size | **340 × 230** logical px | The window, about 900 × 560 |
| Author at | **680 × 460** (2×, for HiDPI) | 1600 × 1000, or SVG |
| Formats | PNG, JPEG, GIF (animated) | Anything WebKit takes: + SVG, WebP, APNG |
| Video | **No.** GdkPixbuf has no MP4 | No `<video>` in the bundle either |

Both are compiled into the binary as GResource, so **file size is binary size**.
A 5 MB GIF is 5 MB of executable shipped to every user. Keep a step image under
~200 KB and an animation under ~600 KB.

Three behaviours worth knowing, all of them recent:

- **The slot never moves.** An asset is scaled to fit 340 × 230, keeping its
  proportions, and is never upscaled. Every step is the same shape whatever you
  give it, so you no longer have to match sizes by hand — but an asset much
  wider than 3:2 will letterbox inside the slot.
- **Animations animate.** A GIF used to be shown as its first frame; it now
  plays. Each frame is scaled at display time, so keep the GIF close to the slot
  size rather than shipping a 1600-wide animation to be shrunk 30 times a second.
- **The accent colour is the desktop's**, not yours: `#2f6fb5` on Regolith,
  `#3584e4` on GNOME, `#3daee9` on KDE. Art that hardcodes one of those looks
  wrong on the other two. Use the neutral palette below and let the accent live
  in the UI around your picture.

## The palette to hand the model

The reference branding's deck is dark. Paste these into every prompt so a set
generated over several sessions still matches:

```
background #232733   foreground #d8e0ee   muted #aab6c8
surface    #2c3243   border     #414a60   accent (sparingly) #6ab0f3
```

## The rule that matters most: no text in generated images

Image models garble text, and even when they get it right you have shipped an
English string inside a PNG that no translator can reach. **Every label the user
reads must be a real widget or real HTML.** Ask for window shapes, panels, key
caps without letters, arrows, cursors — never for words, menus with items, or
terminal output. If a picture only makes sense with a caption, the caption goes
in the step's `description` field, where it is text.

## Keeping a set consistent

Two techniques, both worth more than any single prompt:

1. **A style anchor**, pasted verbatim into every prompt in the set. Change one
   word of it and the set drifts.
2. **Reference the first image.** Once you have one you like, attach it to the
   next prompt: *"match the style, palette, line weight and perspective of the
   attached image exactly; only the content changes."* This is what stops image
   four looking like a different product from image one.

The anchor used below:

> Flat vector illustration, isometric-free straight-on view, thin 2px rounded
> strokes, no gradients except a single subtle one on the background, dark UI
> palette (#232733 background, #d8e0ee lines, #2c3243 surfaces, #414a60 borders),
> generous negative space, no text, no letters, no logos, centred composition
> with 8% padding, 3:2 aspect ratio.

## Prompts: practice-step images

Each is the anchor plus one subject line. Generate at 3:2 and export **680 × 460**.

**Tiling and windows**

1. *Two abstract window rectangles side by side filling a screen edge to edge, no
   gap between them, a thin accent-coloured outline on the left one to show
   focus.*
2. *Four window rectangles in a 2×2 grid filling a screen, one highlighted with a
   thin brighter border.*
3. *One window rectangle expanding to fill the whole screen, a soft motion arc
   behind it suggesting the moment of expansion.*
4. *A single window rectangle floating above two tiled ones, slightly rotated,
   with a soft drop shadow to lift it off the surface.*
5. *A vertical split: one window rectangle dividing into two stacked halves, a
   thin dashed line marking the split.*

**Workspaces and navigation**

6. *Three screen rectangles in a row, the middle one bright and forward, the
   outer two dimmed and slightly smaller, suggesting a strip of workspaces you
   move along.*
7. *A horizontal arrow sweeping from one screen rectangle to the next, motion
   lines trailing, the destination screen brighter.*
8. *A grid of nine small application squares appearing over a dimmed desktop, the
   corner one lifted slightly — an app grid, no icons inside the squares.*

**Input and keys**

9. *A single blank key cap seen straight on, rounded corners, thin stroke, a soft
   glow beneath it as if just pressed. No letter on the cap.*
10. *Two blank key caps joined by a small plus sign between them, both lit, the
    plus in the muted colour.*
11. *A cursor arrow resting on a blank panel, with a subtle ripple beneath the
    tip.*

**Terminal and launching**

12. *An empty terminal window rectangle with a single blank prompt line and a
    solid block cursor, no text anywhere.*
13. *A launcher panel opening as a rounded rectangle over a dimmed desktop, three
    blank rows suggesting results.*
14. *A notification panel sliding down from the top edge of a screen rectangle,
    two blank rounded cards inside it.*

## Prompts: welcome page and slide art

These render in WebKit, so they can be wider, and SVG is ideal — it scales, it is
tiny, and you can restyle it with CSS later.

15. *A wide hero illustration for an onboarding welcome screen: an abstract
    desktop made of overlapping rounded rectangles arranged like a tiled layout,
    receding gently, dark palette, one accent-coloured shape as focal point, deep
    negative space at the left third for a heading to sit over. 16:10, no text.*
16. *A repeating background pattern of very faint window outlines at 4% opacity
    on #232733, seamless, suitable for tiling behind a slide.*
17. *A row of three abstract screens showing the same layout at three stages of
    being arranged, left to right, as a progress narrative. No text.*

Ask for SVG explicitly where you can: *"output as clean SVG with grouped paths
and no embedded raster images."* Then open it and delete the `<title>`/metadata
the model leaves behind.

## Prompts: animations

Ask for the *loop*, not a film. Anything longer than about three seconds is not a
demonstration, it is a distraction next to a step the user is trying to perform.

18. *A 2-second seamless loop: one window rectangle sliding from the right edge
    into place beside another, snapping to fill exactly half the screen, holding
    briefly, then resetting. Flat vector, dark palette, no text, 3:2.*
19. *A 2-second seamless loop: a strip of three workspace rectangles sliding one
    position to the left, easing in and out, then holding.*
20. *A 1.5-second loop: a blank key cap pressing down and releasing, with a ring
    ripple expanding once from beneath it.*

Gemini's video output is MP4 and the app cannot show MP4, so convert. This
produces a small, correctly-sized GIF:

```bash
# 1. a palette from the source, so colours do not band
ffmpeg -i in.mp4 -vf "fps=15,scale=680:-1:flags=lanczos,palettegen=stats_mode=diff" -y palette.png

# 2. the GIF itself, using it
ffmpeg -i in.mp4 -i palette.png \
  -lavfi "fps=15,scale=680:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3" \
  -loop 0 -y out.gif

ls -lh out.gif   # aim well under 600 KB; drop to fps=12 or scale=560 if not
```

## Before you ship a set

- [ ] Every file is at most 680 px on its long edge, and 3:2 or close to it.
- [ ] No words, anywhere, in any image.
- [ ] Opened on a **dark** background — generated art often carries a white halo
      that is invisible on white and obvious on `#232733`.
- [ ] Animations loop cleanly, with no visible jump at the seam.
- [ ] `du -sh` on the branding directory before and after; you are adding this to
      the binary.
- [ ] `./build/linux-onboarding --check-workflows` still passes, and the app has
      been opened once to look at the set as a whole rather than file by file.

A set that is consistent and plain beats a set that is striking and mismatched.
The picture is not the lesson — the shortcut is — and the art's job is to make
the step recognisable at a glance, then get out of the way.
