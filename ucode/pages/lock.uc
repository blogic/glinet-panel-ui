'use strict';

import * as lv from 'lv';
import { C_TXT, C_TXT_DIM, C_SKY, W, H, WX_SKY,
	 TRACK_SPACE } from '../lib/theme.uc';
import { text_new, text_set, icon_new } from '../lib/widget.uc';
import { sky_image, degrees_unit } from '../lib/weather.uc';
import { rate_fmt } from '../lib/rate.uc';
import { centre, chain_at } from '../lib/layout.uc';
import { FONT_REG_15, FONT_THIN_112, FONT_REG_20, FONT_REG_26, FONT_LIGHT_45,
	 IMAGE_WX_CLOUD_LG } from '../lib/assets.uc';

/* A digit only face has no ascenders, so the 112 px clock stands 85 tall and
   none of these is 1.2 times its size. */
const DATE_H	= lv.font_line_height(FONT_REG_20);
const CLOCK_H	= lv.font_line_height(FONT_THIN_112);
const MER_H	= lv.font_line_height(FONT_REG_15);
const RATE_H	= lv.font_line_height(FONT_REG_20);

const DATE_GAP	= 32;
const RATE_GAP	= 34;

const BLOCK_H	= DATE_H + DATE_GAP + CLOCK_H + RATE_GAP + RATE_H;
const DATE_Y	= int((H - BLOCK_H) / 2);
const CLOCK_Y	= DATE_Y + DATE_H + DATE_GAP;
const RATE_Y	= CLOCK_Y + CLOCK_H + RATE_GAP;

const MER_Y	= CLOCK_Y + CLOCK_H + int((RATE_GAP - MER_H) / 2);

const WX_PAD	= 14;
const WX_GAP	= 10;	/* between the readings and the sky */
const WX_COL_W	= 108;
const WX_COND_H	= lv.font_line_height(FONT_REG_15);
const WX_TEMP_H	= lv.font_line_height(FONT_REG_26);
const WX_STACK	= 2;	/* between the condition and the temperature */

const WX_SKY_X	= W - WX_PAD - WX_SKY;
const WX_COL_X	= WX_SKY_X - WX_GAP - WX_COL_W;

const WX_BLOCK_H = WX_COND_H + WX_STACK + WX_TEMP_H;
const WX_COND_Y	= CLOCK_Y + int((CLOCK_H - WX_BLOCK_H) / 2);
const WX_TEMP_Y	= WX_COND_Y + WX_COND_H + WX_STACK;
const WX_SKY_Y	= CLOCK_Y + int((CLOCK_H - WX_SKY) / 2);

const SMALL_H	= lv.font_line_height(FONT_LIGHT_45);
const SMALL_GAP	= 8;	/* between the digits and the weather */
const SMALL_W	= WX_COL_X - SMALL_GAP;
const SMALL_STACK = 2;
const SMALL_BLOCK = SMALL_H + SMALL_STACK + MER_H;

const SMALL_Y	= CLOCK_Y + int((CLOCK_H - SMALL_H) / 2);
const SMALL_Y_MER = CLOCK_Y + int((CLOCK_H - SMALL_BLOCK) / 2);
const SMALL_MER_Y = SMALL_Y_MER + SMALL_H + SMALL_STACK;

/* Fixed cells placed outward from a pinned dot, so no reading can move
   another. Never a flow. */
const RATE_GAP_X = 6;
const RATE_VAL_W = 44;
const RATE_UNIT_W = 31;
const RATE_ARROW_W = 17;
const RATE_DOT_W = 6;

const RATE_CELLS = [ RATE_ARROW_W, RATE_UNIT_W, RATE_VAL_W ];

const RATE_DOT_X = centre(W, RATE_DOT_W);
const RATE_L_AT = chain_at(RATE_DOT_X, RATE_CELLS, RATE_GAP_X, -1);
const RATE_R_AT = chain_at(RATE_DOT_X + RATE_DOT_W, RATE_CELLS, RATE_GAP_X, 1);

let date, clock_big, clock_small, meridiem;
let wx_cond, wx_temp, wx_sky;
let down_val, down_unit, up_val, up_unit;
let state, clock_24h, wx_shown, sky_shown;

function rate_cell(parent, x, w, align, text) {
	let cell = text_new(parent, FONT_REG_20, C_TXT_DIM, text);

	cell.obj.set({ x, y: RATE_Y, w });
	cell.obj.style({ text_align: align });

	return cell;
}

function clock_text() {
	return clock_24h ? state.clock_24 : state.clock_12;
}

function clock_place() {
	if (wx_shown) {
		let small = lv.text_width(FONT_LIGHT_45, clock_text(),
					  TRACK_SPACE);

		clock_small.obj.set({ x: int((SMALL_W - small) / 2),
				      y: clock_24h ? SMALL_Y : SMALL_Y_MER });

		return;
	}

	let digits = lv.text_width(FONT_THIN_112, clock_text(), TRACK_SPACE);

	clock_big.obj.set({ x: int((W - digits) / 2), y: CLOCK_Y });
}

function layout_set(weather) {
	if (wx_shown == weather)
		return;

	wx_shown = weather;

	clock_big.obj.hidden(weather);
	clock_small.obj.hidden(!weather);
	wx_cond.obj.hidden(!weather);
	wx_temp.obj.hidden(!weather);
	wx_sky.hidden(!weather);

	meridiem.obj.set(weather ? { x: 0, y: SMALL_MER_Y, w: SMALL_W }
				 : { x: 0, y: MER_Y, w: W });

	clock_place();
}

function weather_update() {
	let wx = state.weather;

	layout_set(wx != null);

	if (!wx)
		return;

	text_set(wx_cond, wx.text);
	text_set(wx_temp, degrees_unit(wx.temp));

	let sky = sky_image(wx.glyph, wx.day);

	/* Guarded like a reading: an image source is set rather than compared, and
	   this runs every second while the sky changes hourly. */
	if (sky_shown == sky)
		return;

	sky_shown = sky;
	wx_sky.src(sky);
}

function page_build(parent, ctx) {
	state = ctx.state;
	clock_24h = ctx.clock_24h;

	date = text_new(parent, FONT_REG_20, C_TXT_DIM, '');
	date.obj.set({ x: 0, y: DATE_Y, w: W });
	date.obj.style({ text_align: lv.TEXT_ALIGN_CENTER });

	clock_big = text_new(parent, FONT_THIN_112, C_TXT, '');
	clock_big.obj.style({ text_letter_space: TRACK_SPACE });

	clock_small = text_new(parent, FONT_LIGHT_45, C_TXT, '');
	clock_small.obj.style({ text_letter_space: TRACK_SPACE });
	clock_small.obj.hidden(true);

	wx_cond = text_new(parent, FONT_REG_15, C_TXT_DIM, '');
	wx_cond.obj.set({ x: WX_COL_X, y: WX_COND_Y, w: WX_COL_W });
	wx_cond.obj.style({ text_align: lv.TEXT_ALIGN_CENTER });
	wx_cond.obj.hidden(true);

	wx_temp = text_new(parent, FONT_REG_26, C_TXT, '');
	wx_temp.obj.set({ x: WX_COL_X, y: WX_TEMP_Y, w: WX_COL_W });
	wx_temp.obj.style({ text_align: lv.TEXT_ALIGN_CENTER });
	wx_temp.obj.hidden(true);

	wx_sky = icon_new(parent, IMAGE_WX_CLOUD_LG, C_SKY);
	wx_sky.set({ x: WX_SKY_X, y: WX_SKY_Y });
	wx_sky.hidden(true);

	meridiem = text_new(parent, FONT_REG_15, C_TXT_DIM, '');
	meridiem.obj.set({ x: 0, y: MER_Y, w: W });
	meridiem.obj.style({ text_align: lv.TEXT_ALIGN_CENTER });
	meridiem.obj.hidden(clock_24h);

	rate_cell(parent, RATE_DOT_X, RATE_DOT_W, lv.TEXT_ALIGN_CENTER, '·');

	rate_cell(parent, RATE_L_AT[0], RATE_ARROW_W, lv.TEXT_ALIGN_CENTER, '↓');
	down_unit = rate_cell(parent, RATE_L_AT[1], RATE_UNIT_W,
			      lv.TEXT_ALIGN_CENTER, '');
	down_val = rate_cell(parent, RATE_L_AT[2], RATE_VAL_W,
			     lv.TEXT_ALIGN_RIGHT, '');

	rate_cell(parent, RATE_R_AT[0], RATE_ARROW_W, lv.TEXT_ALIGN_CENTER, '↑');
	up_unit = rate_cell(parent, RATE_R_AT[1], RATE_UNIT_W,
			    lv.TEXT_ALIGN_CENTER, '');
	up_val = rate_cell(parent, RATE_R_AT[2], RATE_VAL_W,
			   lv.TEXT_ALIGN_LEFT, '');
}

function page_update(source) {
	let now = clock_text();
	let moved = clock_big.last != now;

	text_set(date, state.date);
	text_set(clock_big, now);
	text_set(clock_small, now);

	if (!clock_24h)
		text_set(meridiem, state.meridiem);

	weather_update();

	if (moved)
		clock_place();

	let down = rate_fmt(state.rx[-1] ?? 0);
	let up = rate_fmt(state.tx[-1] ?? 0);

	text_set(down_val, down.value);
	text_set(down_unit, down.unit);
	text_set(up_val, up.value);
	text_set(up_unit, up.unit);
}

return {
	needs: [ 'clock', 'wan', 'weather' ],
	build: page_build,
	enter: page_update,
	update: page_update
};
