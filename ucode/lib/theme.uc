'use strict';

import { W } from 'lvgl.theme';

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
