'use strict';

import * as lv from 'lv';
import { FONT_SEMI_21 } from './assets.uc';

/*
 * A name says what a colour is for, not what it looks like. Nine of the sixteen
 * are neutral, because the panel is mostly type on glass.
 *
 * Values one or two steps apart in RGB565 are the same colour on this display,
 * so a shade only earns a name where it carries a different meaning.
 */

export const C_SCREEN	= 0x000000;
export const C_SURFACE	= 0x1c1c1e;
/* A surface lifted off the one beneath: a pressed row, the back circle, a
   dialog over its scrim. Without haptics the pressed step is the only
   affordance a row has, so it is a step of fill and not an animation. */
export const C_RAISED	= 0x2c2c2e;

/* Present but inactive: the off track of a switch, an unlit page dot. A
   different idea from the structural C_RULE, and a step darker. */
export const C_IDLE	= 0x3e3e44;
/* Down rather than merely inactive: a status dot that is off, and the hairline
   inside a dialog, which sits on C_RAISED and needs more than C_IDLE. */
export const C_DOWN	= 0x48484a;

/* Everything structural: the line between rows, the unfilled part of a gauge,
   a count beside a title. Two steps up the iOS dark grey ladder from 0x38383a,
   because a single pixel of anything darker is invisible on this glass. */
export const C_RULE	= 0x636366;

/* Type takes two tiers and no more. White names the thing; the dim tier carries
   what qualifies it, and a mark at full brightness is white like a word. */
export const C_TXT	= 0xffffff;
export const C_TXT_DIM	= 0x9a9aa2;

/* The filled part of the brightness bar. Not pure white: the bar is a control
   and would otherwise read as a lit panel rather than a thing to drag. */
export const C_FILL	= 0xe8e8ec;

/* Two series, which tell one line from another and never mean quality. */
export const C_SERIES	= 0x0a6cff;
export const C_SERIES_ALT = 0x64d2ff;
/* A third and separate idea, close to C_SERIES and never drawn beside it: this
   one means touchable. */
export const C_ACTION	= 0x0a84ff;

/* State. Colour carries meaning, never decoration, and normally sits beside a
   word saying the same thing. Good needs no colour. */
export const C_OK	= 0x32d74b;
export const C_WARN	= 0xff9f0a;
export const C_ALERT	= 0xff453a;

export const W		= 320;
export const H		= 240;

/* Cards are full bleed: they meet the top and both sides of the glass, and only
   the bottom is held back, to clear the page dots. */
export const CARD_X	= 0;
export const CARD_W	= W;
export const CARD_PAD	= 10;
export const CARD_RADIUS = 12;
export const SEP_H	= 1;

/* Negative tracking, which the display sizes of Inter want and the small ones do not. */
export const TRACK_SPACE = -2;

/*
 * The v3 grid. A list group is inset from both edges and rounded, unlike the
 * full bleed cards above it, because a list of rows reads as one object sitting
 * on the glass rather than as the glass itself.
 */
export const GROUP_X	= 10;
export const GROUP_W	= W - 2 * GROUP_X;
export const GROUP_RADIUS = 9;

/*
 * A root shows three rows and a sub page four. The glass is small and a root is
 * what the panel is read at across a desk, so it spends its height on fewer,
 * larger rows; a sub page is read at arm's length and carries more detail, so
 * it packs tighter. The separator is inset by ROW_PAD at both ends, so it stops
 * where the text does on either side.
 *
 * A root fills its space exactly: 3 x 60 plus 2 hairlines is 182 of the 184 it
 * has under a fixed header. A sub page has the same 184 and four rows come to
 * 195, so a full one scrolls inside its card by 11 px. That is deliberate: the
 * alternative was letting sub pages run to the bottom edge while roots stop
 * short of it.
 */
export const ROW_H	= 48;
export const ROW_H_ROOT	= 60;
export const ROW_PAD	= 11;
export const ROW_GAP	= 9;

/*
 * The header does not scroll. v3 had it as the first item of the scroll
 * content, which reads well on a phone and badly here: on a 240 px panel the
 * page loses the only thing naming it as soon as the list moves, and the back
 * circle would go with it. Header and back stay put; only the payload scrolls.
 */
export const HEAD_TOP	= 11;
export const HEAD_X	= 12;
export const HEAD_BOTTOM = 7;
export const HEAD_INDENT = 40;

/*
 * The lock sits opposite the header on every page that can be left, and is the
 * way out: it puts the panel back to idle at once, which with a PIN set means
 * the next person has to enter it. The icon is small, so the hit area is not.
 */
export const LOCK_SIZE	= 14;
export const LOCK_X	= W - 12 - LOCK_SIZE;
export const LOCK_Y	= 15;
export const LOCK_HIT	= 44;

/* The back circle floats over the content rather than sitting in a bar. */
export const BACK_SIZE	= 28;
export const BACK_X	= 6;
export const BACK_Y	= 6;

/* Page dots, roots only. */
export const DOT_SIZE	= 5;
export const DOT_GAP	= 10;
export const DOT_BOTTOM	= 5;

/*
 * The brightness bar: one control on the page and nothing else, so it takes the
 * full group width and a height a thumb can find without looking.
 */
export const BAR_H	= 48;
export const BAR_RADIUS	= 24;
export const BAR_ICON	= 18;
export const BAR_ICON_X	= 12;
/* The fill never shrinks past the sun, or the icon lands on the dark track and
   disappears. Below that the bar stops being a readout and stays an affordance. */
export const BAR_FILL_MIN = 46;

/*
 * The PIN screen. It has no chrome and no way out, because nothing else can
 * happen until it is satisfied, so it is the one page that spends the whole
 * 240 px on itself.
 */
export const PIN_LEN	= 6;
export const PIN_PAD	= 10;
export const PIN_TOP	= 12;
export const PIN_BOTTOM	= 8;
export const PIN_DOT	= 10;
export const PIN_DOT_GAP = 11;
export const PIN_KEY_GAP = 5;

/*
 * Both stop the same distance above the bottom of the glass. A root spends that
 * strip on its dot row and a sub page leaves it empty, but a card that ran to
 * the edge on one and not on the other would read as a mistake, and the rounded
 * foot that says where a list ends would be off screen on the sub page.
 */
export const LIST_H	= H - 12;
export const LIST_H_SUB	= LIST_H;

/*
 * The header is as tall as the face it is set in, read from the face itself
 * rather than copied out of it, so it cannot drift when the fonts are cut
 * again. Regenerating the set once already moved every line height by a pixel.
 */
export const HEAD_H	= HEAD_TOP + lv.font_line_height(FONT_SEMI_21) + HEAD_BOTTOM;

/*
 * The strip a page draws into, under the fixed header. Nine pages held back
 * five different amounts from the bottom of the glass for what is one region,
 * so there is one of it here and none of them keeps its own.
 */
export const BODY_Y	= HEAD_H;
export const BODY_H	= LIST_H - HEAD_H;

/*
 * A rule drawn across a page that has no card. The separator inside a group is
 * a different idea and keeps its own inset, which is left aligned only.
 */
export const RULE_PAD	= 14;

/*
 * The weather page. The sky glyphs are the one thing on the panel that is not
 * text, a reading or a state, so they carry their own tint: white would make
 * them read as another label and the interactive blue would say they can be
 * tapped.
 */
export const C_SKY	= 0xc9d4ff;

/*
 * The current conditions. The region is the 65 px between the header and the
 * rule, and the temperature, the two lines of text and the sky glyph are all
 * centred on the same line through it rather than each sitting where it landed.
 *
 * The degree is placed at run time, not from a constant: it hangs off the end of
 * the temperature, and that is two glyphs at 18 degrees, one at 9 and three at
 * a hundred, with a minus in front of it in a German winter.
 */
export const WX_TEMP_X	= 16;
export const WX_TEMP_Y	= 59;
export const WX_DEG_GAP	= 3;
export const WX_DEG_DY	= -7;
export const WX_TEXT_X	= 87;
export const WX_COND_Y	= 54;
export const WX_FEELS_Y	= 79;
export const WX_SKY	= 40;
export const WX_SKY_X	= W - 14 - WX_SKY;
export const WX_SKY_Y	= 56;

export const WX_RULE_Y	= 109;

/*
 * Five columns on a 61 px pitch, which is what the forecast holds: six would put
 * the day names closer than their own width and five is what the API is asked
 * for. Everything in a column is centred on it.
 */
export const WX_DAYS	= 5;
export const WX_COL_W	= 61;
export const WX_COL_X	= int((W - WX_DAYS * WX_COL_W) / 2);

/*
 * The block fills the space under the rule rather than sitting at the top of
 * it. There are 119 px between the rule and the dot row and the forecast used
 * 71 of them, which left a gap above it wide enough to read as a mistake and
 * none below. At this size a column is read across a desk, which is the whole
 * reason the page exists.
 *
 * Laid out on line heights, so the space between the rows is the leading the
 * faces already carry rather than a gap invented on top of it.
 */
export const WX_DAY_Y	= 117;
export const WX_ICON_Y	= 143;
export const WX_HI_Y	= 177;
export const WX_LO_Y	= 202;

/* The attribution opener, on the header line after the title. */
export const WX_INFO	= 17;
export const WX_INFO_Y	= 14;
export const WX_INFO_GAP = 6;
