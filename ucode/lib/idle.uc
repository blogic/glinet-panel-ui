'use strict';

import { WX_SKY } from './theme.uc';

/*
 * Where the idle screen puts its parts. Pure arithmetic over the screen size,
 * the font heights and the measured text widths, so it can be checked without
 * a display (test/idle-layout.uc).
 *
 * Landscape keeps the layout it always had. Upright, 240 px is too narrow for
 * "23:57" in the 112 px face, so the hours stand over the minutes; with the
 * weather, the small clock sits over a centred weather row instead of beside
 * it.
 */

const DATE_GAP	= 32;
const RATE_GAP	= 34;
const LINE_GAP	= 6;	/* between hours and minutes, upright */

const WX_PAD	= 14;
const WX_GAP	= 10;	/* between the readings and the sky */
const WX_COL_W	= 108;
const WX_STACK	= 2;	/* between the condition and the temperature */

const SMALL_GAP	= 8;	/* between the digits and the weather, side by side */
const SMALL_STACK = 2;
const ROW_GAP	= 14;	/* between the digits and the weather, stacked */

/* The rate row: fixed cells placed outward from a pinned dot. */
export const RATE_GAP_X	= 6;
export const RATE_VAL_W	= 44;
export const RATE_UNIT_W = 31;
export const RATE_ARROW_W = 17;
export const RATE_DOT_W	= 6;

const RATE_SIDE_W = RATE_ARROW_W + RATE_UNIT_W + RATE_VAL_W + 3 * RATE_GAP_X;

function rect(x, y, w, h) {
	return { x, y, w, h };
}

/**
 * idle_layout - the idle screen's parts for one screen and mode
 * @o: w and h, the screen; h24, the clock form; weather, whether it shows;
 *     fonts, the line heights date_h, clock_h, mer_h, rate_h, small_h, cond_h
 *     and temp_h; widths, the measured clock (one line), clock_line (two
 *     digits) and small
 *
 * Return: a rect { x, y, w, h } for every part, shown, the names of the
 * parts this mode puts on screen, clock_lines, 1 or 2, and portrait.
 */
export function idle_layout(o) {
	let f = o.fonts, w = o.w, h = o.h;
	let portrait = h > w;
	let lines = portrait ? 2 : 1;
	let slot_h = lines * f.clock_h + (lines - 1) * LINE_GAP;
	let block_h = f.date_h + DATE_GAP + slot_h + RATE_GAP + f.rate_h;
	let date_y = int((h - block_h) / 2);
	let clock_y = date_y + f.date_h + DATE_GAP;
	let rate_y = clock_y + slot_h + RATE_GAP;
	let clock_w = portrait ? o.widths.clock_line : o.widths.clock;
	let dot_x = int((w - RATE_DOT_W) / 2);
	let l = {
		portrait,
		clock_lines: lines,
		slot: rect(0, clock_y, w, slot_h),
		date: rect(0, date_y, w, f.date_h),
		clock: rect(int((w - clock_w) / 2), clock_y, clock_w, slot_h),
		meridiem: rect(0, clock_y + slot_h + int((RATE_GAP - f.mer_h) / 2),
			       w, f.mer_h),
		rate: rect(dot_x - RATE_SIDE_W, rate_y,
			   2 * RATE_SIDE_W + RATE_DOT_W, f.rate_h),
		rate_dot_x: dot_x
	};

	let wx_block_h = f.cond_h + WX_STACK + f.temp_h;
	let small_block_h = f.small_h + (o.h24 ? 0 : SMALL_STACK + f.mer_h);
	let small_w = o.widths.small;
	let col_x, sky_x, row_y, small_x, small_y;

	if (portrait) {
		/* The digits over a centred row of readings and sky. */
		let row_w = WX_COL_W + WX_GAP + WX_SKY;
		let row_h = wx_block_h > WX_SKY ? wx_block_h : WX_SKY;
		let stack_h = small_block_h + ROW_GAP + row_h;

		small_y = clock_y + int((slot_h - stack_h) / 2);
		small_x = int((w - small_w) / 2);
		row_y = small_y + small_block_h + ROW_GAP;
		col_x = int((w - row_w) / 2);
		sky_x = col_x + WX_COL_W + WX_GAP;

		l.cond = rect(col_x, row_y + int((row_h - wx_block_h) / 2),
			      WX_COL_W, f.cond_h);
		l.sky = rect(sky_x, row_y + int((row_h - WX_SKY) / 2),
			     WX_SKY, WX_SKY);
	}
	else {
		/* The digits on the left, readings and sky on the right, all in
		   the slot the big clock would fill. */
		sky_x = w - WX_PAD - WX_SKY;
		col_x = sky_x - WX_GAP - WX_COL_W;

		let small_room = col_x - SMALL_GAP;

		small_y = clock_y + int((slot_h - small_block_h) / 2);
		small_x = int((small_room - small_w) / 2);

		l.cond = rect(col_x, clock_y + int((slot_h - wx_block_h) / 2),
			      WX_COL_W, f.cond_h);
		l.sky = rect(sky_x, clock_y + int((slot_h - WX_SKY) / 2),
			     WX_SKY, WX_SKY);
	}

	/* The width the small clock centres itself in, as its digits change. */
	l.small_room = portrait ? w : col_x - SMALL_GAP;
	l.temp = rect(col_x, l.cond.y + f.cond_h + WX_STACK, WX_COL_W, f.temp_h);
	l.small = rect(small_x, small_y, small_w, f.small_h);
	l.small_mer = rect(small_x, small_y + f.small_h + SMALL_STACK, small_w,
			   f.mer_h);

	if (o.weather)
		l.shown = [ 'date', 'small', 'cond', 'temp', 'sky', 'rate' ];
	else
		l.shown = [ 'date', 'clock', 'rate' ];

	if (!o.h24)
		push(l.shown, o.weather ? 'small_mer' : 'meridiem');

	return l;
};
