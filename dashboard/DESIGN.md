# Design system — sonyliv-mock dashboard

Recorded from the built surface, not from intentions. Every value below is in
`app/globals.css` or a component; if the two disagree, the code is right and this
file is stale.

**Not to be confused with [`docs/DESIGN.md`](../docs/DESIGN.md)**, which is the
ClickHouse solution architecture. This file is the visual system only.

## Where it comes from

Measured off `sonyliv.com` on 2026-08-02 with a headless browser, reading computed
styles rather than recalling the brand:

| | measured | how |
|---|---|---|
| Ground | `#000000` | 6.2M px² of painted area, dominant by a wide margin |
| Surface | `#222222` | 950k px² |
| Text | `#FFFFFF`, `#AAAAAA`, `#A5A5A5` | by element count |
| Accent | `#FFA800` | logo tick, active-nav border, Subscribe control |
| Type | Inter 400/500/600 | `Inter-Regular` / `-Medium` / `-Semibold` in computed `font-family` |
| Radii | `4px` (39 uses), `10px` (30 uses) | a strict two-step system |

The site also embeds SF Pro Display/Text and Roboto as fallbacks. Inter is what
actually renders, so Inter is what this app self-hosts.

## The one rule

**One signal colour.** SonyLIV's whole home page carries a single non-neutral —
`#FFA800`. Everything else is black, white and two greys. This app keeps that,
which means hierarchy is carried by **form**, not by inventing hues:

- fill vs outline vs text (`Button`'s three variants)
- solid vs dashed (the two lines in `DualCurveChart`)
- weight and size

`--color-live` is deliberately the *same value* as `--color-accent`. The token
exists so component code reads by meaning. **Do not fork it into a teal or a
green.** Where two live quantities must be distinguished — fleet vs pipeline on the
concurrency chart — the second is white and dashed, which is SonyLIV's own
gold-over-white hierarchy rather than a colour we made up.

Red (`#FF5A5F`) is the one addition, and it is an addition: an operator's tool has
to be able to say "this is wrong" and a brand surface never needs to.

## Tokens

```
ground   #000000      sunken  #0a0a0a      panel  #141414      raised  #222222
line     #2e2e2e      line-soft #1c1c1c
ink      #ffffff      ink-2   #aaaaaa      ink-3  #8a8a8a
accent   #ffa800      accent-dim #7a5200   accent-wash #2a1c00
bad      #ff5a5f      bad-wash #2a1011
radius-sm/DEFAULT 4px          radius-lg 10px
```

Contrast on `#000`: accent 10.9:1, ink-2 9.0:1, ink-3 6.0:1. `ink-3` is derived,
not measured — SonyLIV needs two text steps, a dashboard needs three, and the third
still has to pass 4.5:1 as body text.

## Type

Inter, self-hosted by `next/font` (latin, 400/500/600). Mono is the system stack
and carries only measurements, timestamps and ids — never used as a costume for
"technical".

`.eyebrow` (10px/600/0.1em, uppercase) is set in Inter, not mono: SonyLIV sets its
chrome in the text face, and at 10px mono's wider figures cost more room than they
earn.

## Conventions worth keeping

- **No coloured left rules.** Panels are flat fields separated by a hairline; state
  lands on the title, which is the element that names it. The 2px accent
  `border-l` this replaced made eight distinct panels read as eight identical cards.
- **`min-w-0` on every grid/flex item that contains a table.** `Panel` and `main`
  both carry it. Without it a grid item's default `min-width: auto` refuses to
  shrink below content — measured at a 537px column inside 350px, which put the
  whole page into horizontal scroll on a 390px viewport.
- **The nav wraps below `lg`; it does not hide.** The rule here used to be "it
  scrolls, it does not wrap", and it was wrong in a specific way: the tab strip is
  the only `min-w-0` item in the header row, so it absorbed the whole shortfall
  and collapsed to zero width while the lockup, the dataset picker and the
  external links all still rendered. A header that drops its own navigation first
  has its priorities backwards. Below 1024px the chrome takes row one and the tabs
  take a full-width scrollable row two — measured at 768px, where inline tabs fit
  only by clipping the active one to a single letter.

- **A native `<select>` gets an explicit width, never a `max-width`.** Its
  intrinsic minimum is its longest *option*, not its value, so the dataset picker
  refused to shrink and overlapped the links beside it. `truncate` has no effect
  on a select's own rendering either. A fixed width ends the negotiation and lets
  the browser ellipsise the label.

- **Charts carry no hue the system has not already earned.** The analytics charts
  used to distinguish their second series with `#5b9dd9`. That broke the one rule
  below, and for nothing: the second series is now white and dashed, which is
  SonyLIV's own gold-over-white hierarchy, survives a projector and a greyscale
  screenshot, and works for a reader who cannot separate blue from grey. Ranked
  bars separate their two quantities the same way — filled is a peak and must not
  be summed, outlined is viewer-hours and is additive.

- **The chart key is DOM, not canvas.** Chart.js cannot draw a 2px dashed swatch
  at 11px without it collapsing to a dot, which left two identical-looking
  entries beside two visibly different lines. `ChartLegend` draws each swatch as
  the line it stands for, in the app's own type.

- **Loading is a skeleton that holds the panel's height**, never a spinner.
  Six panels resolve at different times; a spinner in the middle of each one
  reflows everything below it on every refetch.

- **Absent is not zero, and both have to look different from broken.** A withheld
  peak is `NULL` and the series simply is not drawn; an empty window says the
  minute tier may not have published yet; a failed query shows its own message.
  On a serving layer these are three different facts and the UI never collapses
  them.
- **The lockup uses both parties' real marks**, not lettering set in Inter:
  SonyLIV's own header PNG (`public/sonyliv-mark.png`, from their CDN) beside
  ClickHouse's own symbol and wordmark (`components/BrandMarks.tsx`, the same 9×8
  geometry the submission deck draws). Two brands in one lockup is exactly where
  an approximation shows.

  **One line, and both marks in their own colours** — revised from the stacked,
  mono version this file used to describe. The stack existed because two
  *wordmarks* side by side read as a hyphenated product name; leading the
  ClickHouse side with its symbol solves that better, and costs half the header's
  vertical budget, which the nav now spends on tabs. Colour is the one deliberate
  exception to the one-signal-colour rule below: hue is reserved for state
  everywhere else, but a logo is not state — it is someone else's property, and
  the rule that stops the interface inventing hues is not a licence to restyle a
  mark that is not ours. It also matches `pitch/index.html`; a deck and a product
  that lock up their brands differently read as two projects.

  The `×` is typographic and sits at `ink-3`. It used to be the header's only
  gold, back when the ClickHouse side was mono and the join carried the emphasis;
  with two coloured marks a gold `×` would be a third accent competing with both.

## Deliberately not done

- No light theme. Dark is the brand's own ground and the operator's real scene
  (beside a terminal, watching a live curve), not a category default.
- No charting library. Two series and a hover readout do not justify the bytes in a
  static export.
- No icon set. Nothing here needed one; if it does, draw SVGs in one stroke weight
  rather than reaching for emoji.
