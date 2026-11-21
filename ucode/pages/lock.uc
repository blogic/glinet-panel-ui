'use strict';

import * as lv from 'lv';
import { C_TXT, C_TXT_DIM, C_SKY, W, H, TRACK_SPACE } from 'lvgl.theme';
import { text_new, text_set, icon_new } from 'lvgl.widget';
import { sky_image, degrees_unit } from '../lib/weather.uc';
import { rate_fmt } from 'lvgl.rate';
import { chain_at } from 'lvgl.layout';
import { FONT_REG_15, FONT_THIN_112, FONT_REG_20, FONT_REG_26,
	 FONT_LIGHT_45 } from 'lvgl.assets';
import { IMAGE_WX_CLOUD_LG } from '../lib/assets.uc';
import { idle_layout, RATE_GAP_X, RATE_VAL_W, RATE_UNIT_W, RATE_ARROW_W,
	 RATE_DOT_W } from '../lib/idle.uc';

/* A digit only face has no ascenders, so the 112 px clock stands 85 tall and
   none of these is 1.2 times its size. */
const FONTS = {
	date_h: lv.font_line_height(FONT_REG_20),
	clock_h: lv.font_line_height(FONT_THIN_112),
	mer_h: lv.font_line_height(FONT_REG_15),
	rate_h: lv.font_line_height(FONT_REG_20),
	small_h: lv.font_line_height(FONT_LIGHT_45),
	cond_h: lv.font_line_height(FONT_REG_15),
	temp_h: lv.font_line_height(FONT_REG_26)
};

/* Nominal widths for the layout; the clock still centres on its own text. */
const WIDTHS = {
	clock: lv.text_width(FONT_THIN_112, '23:57', TRACK_SPACE),
	clock_line: lv.text_width(FONT_THIN_112, '23', TRACK_SPACE),
	small: lv.text_width(FONT_LIGHT_45, '23:57', TRACK_SPACE)
};

/* Fixed cells placed outward from a pinned dot, so no reading can move
   another. Never a flow. */
const RATE_CELLS = [ RATE_ARROW_W, RATE_UNIT_W, RATE_VAL_W ];

let date, clock_big, clock_small, meridiem;
let wx_cond, wx_temp, wx_sky;
let down_val, down_unit, up_val, up_unit;
let state, clock_24h, wx_shown, sky_shown;
let plain, wx;		/* the layout without and with the weather */

function rate_cell(parent, x, w, align, text) {
	let cell = text_new(parent, FONT_REG_20, C_TXT_DIM, text);

	cell.obj.set({ x, y: plain.rate.y, w });
	cell.obj.style({ text_align: align });

	return cell;
}

/* Upright, the hours stand over the minutes. */
function clock_text() {
	let now = clock_24h ? state.clock_24 : state.clock_12;

	return plain.portrait ? replace(now ?? '', ':', '\n') : now;
}

function small_text() {
	return clock_24h ? state.clock_24 : state.clock_12;
}

function clock_place() {
	if (wx_shown) {
		let small = lv.text_width(FONT_LIGHT_45, small_text(),
					  TRACK_SPACE);

		clock_small.obj.set({ x: int((wx.small_room - small) / 2),
				      y: wx.small.y });

		return;
	}

	/* Two lines centre themselves across the full width. */
	if (plain.portrait)
		return;

	let digits = lv.text_width(FONT_THIN_112, clock_text(), TRACK_SPACE);

	clock_big.obj.set({ x: int((W - digits) / 2), y: plain.clock.y });
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

	meridiem.obj.set(weather
		? { x: 0, y: wx.small_mer.y, w: wx.small_room }
		: { x: 0, y: plain.meridiem.y, w: W });

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

	let opts = { w: W, h: H, h24: clock_24h, fonts: FONTS, widths: WIDTHS };

	plain = idle_layout({ ...opts, weather: false });
	wx = idle_layout({ ...opts, weather: true });

	date = text_new(parent, FONT_REG_20, C_TXT_DIM, '');
	date.obj.set({ x: 0, y: plain.date.y, w: W });
	date.obj.style({ text_align: lv.TEXT_ALIGN_CENTER });

	clock_big = text_new(parent, FONT_THIN_112, C_TXT, '');
	clock_big.obj.style({ text_letter_space: TRACK_SPACE });

	if (plain.portrait) {
		clock_big.obj.set({ x: 0, y: plain.clock.y, w: W });
		clock_big.obj.style({ text_align: lv.TEXT_ALIGN_CENTER,
				      text_line_space: plain.clock.h -
						       2 * FONTS.clock_h });
	}

	clock_small = text_new(parent, FONT_LIGHT_45, C_TXT, '');
	clock_small.obj.style({ text_letter_space: TRACK_SPACE });
	clock_small.obj.hidden(true);

	wx_cond = text_new(parent, FONT_REG_15, C_TXT_DIM, '');
	wx_cond.obj.set({ x: wx.cond.x, y: wx.cond.y, w: wx.cond.w });
	wx_cond.obj.style({ text_align: lv.TEXT_ALIGN_CENTER });
	wx_cond.obj.hidden(true);

	wx_temp = text_new(parent, FONT_REG_26, C_TXT, '');
	wx_temp.obj.set({ x: wx.temp.x, y: wx.temp.y, w: wx.temp.w });
	wx_temp.obj.style({ text_align: lv.TEXT_ALIGN_CENTER });
	wx_temp.obj.hidden(true);

	wx_sky = icon_new(parent, IMAGE_WX_CLOUD_LG, C_SKY);
	wx_sky.set({ x: wx.sky.x, y: wx.sky.y });
	wx_sky.hidden(true);

	meridiem = text_new(parent, FONT_REG_15, C_TXT_DIM, '');
	meridiem.obj.set({ x: 0, y: plain.meridiem.y, w: W });
	meridiem.obj.style({ text_align: lv.TEXT_ALIGN_CENTER });
	meridiem.obj.hidden(clock_24h);

	let dot_x = plain.rate_dot_x;
	let RATE_L_AT = chain_at(dot_x, RATE_CELLS, RATE_GAP_X, -1);
	let RATE_R_AT = chain_at(dot_x + RATE_DOT_W, RATE_CELLS, RATE_GAP_X, 1);

	rate_cell(parent, dot_x, RATE_DOT_W, lv.TEXT_ALIGN_CENTER, '·');

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
	text_set(clock_small, small_text());

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
