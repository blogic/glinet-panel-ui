'use strict';

import * as lv from 'lv';
import { FONT_REG_15, FONT_REG_20, FONT_SEMI_21, FONT_LIGHT_45, IMAGE_INFO,
	 IMAGE_WX_CLOUD_LG, IMAGE_WX_CLOUD_SM } from '../lib/assets.uc';
import { C_TXT, C_TXT_DIM, C_RULE, C_ACTION, C_SKY, W, SEP_H, HEAD_X,
	 WX_TEMP_X, WX_TEMP_Y, WX_DEG_GAP, WX_DEG_DY, WX_TEXT_X, WX_COND_Y,
	 WX_FEELS_Y, WX_SKY, WX_SKY_X, WX_SKY_Y, WX_RULE_Y, WX_DAYS, WX_COL_W,
	 WX_COL_X, WX_DAY_Y, WX_ICON_Y, WX_HI_Y, WX_LO_Y, WX_INFO,
	 WX_INFO_Y, WX_INFO_GAP, RULE_PAD } from '../lib/theme.uc';
import { header_new, label_new, box_new, icon_new, text_new, text_set,
	 dialog_new } from '../lib/widget.uc';
import { cells_at, centre } from '../lib/layout.uc';
import { sky_image, sky_small, degrees, degrees_unit,
	 NO_READING } from '../lib/weather.uc';

const TITLE = 'Weather';

const CREDIT_TITLE = 'Weather data';
const CREDIT_BODY = 'Forecasts by Open-Meteo.com, from national weather ' +
		    'services including DWD, ECMWF and NOAA.\n\n' +
		    'Licensed under CC BY 4.0.';

let state, activity, defer;
let parent_obj;
let temp, degree, cond, feels, sky, credit;
let columns = [];
let shown;

function reading() {
	return state.weather;
}

function degree_place(text) {
	degree.set({ x: WX_TEMP_X + lv.text_width(FONT_LIGHT_45, text) + WX_DEG_GAP,
		     y: WX_TEMP_Y + WX_DEG_DY });
}

function signature() {
	let now = reading();

	if (!now)
		return '';

	let parts = [ now.temp, now.feels, now.glyph, now.text, now.day ];

	for (let day in now.days)
		push(parts, sprintf('%s|%s|%s|%s', day.name, day.glyph,
				    day.hi, day.lo));

	return join('\n', parts);
}

function credit_close() {
	activity();

	if (!credit)
		return;

	let doomed = credit;

	credit = null;

	defer(function() {
		doomed.close();
	});
}

function credit_show() {
	activity();

	if (credit)
		return;

	credit = dialog_new(parent_obj, {
		title: CREDIT_TITLE,
		body: CREDIT_BODY,
		align: lv.TEXT_ALIGN_LEFT,
		activity,
		choices: [ { text: 'Done', color: C_ACTION, on: credit_close } ]
	});
}

function info_build(parent) {
	let hit = lv.obj(parent);
	let x = HEAD_X + lv.text_width(FONT_SEMI_21, TITLE) + WX_INFO_GAP;

	hit.set({ x: x - WX_INFO_GAP, y: 0, w: WX_INFO + 2 * WX_INFO_GAP,
		  h: WX_INFO_Y + WX_INFO + WX_INFO_GAP });
	hit.style({ bg_opa: lv.OPA_TRANSP, border_width: 0, pad_all: 0,
		    radius: 0 });
	hit.clickable(true);
	hit.scrollable(false);

	icon_new(hit, IMAGE_INFO, C_TXT_DIM)
		.set({ x: WX_INFO_GAP, y: WX_INFO_Y });

	hit.on(lv.EVENT_CLICKED, function() {
		defer(credit_show);
	});
}

/* One pitch, with the gap folded into the column width. */
const COL_AT = cells_at(WX_COL_X, WX_COL_W, WX_DAYS, 0);

function column_build(parent, i) {
	let x = COL_AT[i];
	let col = {};

	col.name = text_new(parent, FONT_REG_20, C_TXT_DIM, '');
	col.name.obj.set({ x, y: WX_DAY_Y, w: WX_COL_W });
	col.name.obj.style({ text_align: lv.TEXT_ALIGN_CENTER });

	/* Centred on what the glyph measures, not on a constant beside it: the
	   constant said 32 while every small sky glyph is 18, so the icon sat
	   seven pixels left of the day it belongs to. */
	col.icon = icon_new(parent, IMAGE_WX_CLOUD_SM, C_SKY);
	col.icon.set({ x: x + centre(WX_COL_W, col.icon.width()),
		       y: WX_ICON_Y });

	col.hi = text_new(parent, FONT_SEMI_21, C_TXT, '');
	col.hi.obj.set({ x, y: WX_HI_Y, w: WX_COL_W });
	col.hi.obj.style({ text_align: lv.TEXT_ALIGN_CENTER });

	col.lo = text_new(parent, FONT_SEMI_21, C_RULE, '');
	col.lo.obj.set({ x, y: WX_LO_Y, w: WX_COL_W });
	col.lo.obj.style({ text_align: lv.TEXT_ALIGN_CENTER });

	return col;
}

function page_update(source) {
	let sig = signature();

	if (shown == sig)
		return;

	shown = sig;

	let now = reading();

	if (!now) {
		text_set(temp, NO_READING);
		degree_place(NO_READING);
		text_set(cond, 'No forecast');
		text_set(feels, '');

		for (let col in columns) {
			text_set(col.name, '');
			text_set(col.hi, '');
			text_set(col.lo, '');
			col.icon.hidden(true);
		}

		degree.hidden(true);
		sky.hidden(true);

		return;
	}

	degree.hidden(now.temp == null);
	sky.hidden(false);

	text_set(temp, degrees(now.temp));
	degree_place(temp.last);
	text_set(cond, now.text);
	sky.src(sky_image(now.glyph, now.day));

	text_set(feels, sprintf('Feels %s', degrees_unit(now.feels)));

	for (let i = 0; i < length(columns); i++) {
		let col = columns[i];
		let day = now.days[i];

		if (!day) {
			text_set(col.name, '');
			text_set(col.hi, '');
			text_set(col.lo, '');
			col.icon.hidden(true);

			continue;
		}

		text_set(col.name, day.name);
		text_set(col.hi, degrees_unit(day.hi));
		text_set(col.lo, degrees_unit(day.lo));
		col.icon.hidden(false);
		col.icon.src(sky_small(day.glyph));
	}
}

function page_build(parent, ctx) {
	state = ctx.state;
	activity = ctx.activity;
	defer = ctx.defer;
	parent_obj = parent;

	header_new(parent, TITLE);
	info_build(parent);

	temp = text_new(parent, FONT_LIGHT_45, C_TXT, '');
	temp.obj.set({ x: WX_TEMP_X, y: WX_TEMP_Y });

	degree = label_new(parent, FONT_REG_15, C_TXT, '°');

	cond = text_new(parent, FONT_REG_20, C_TXT, '');
	cond.obj.set({ x: WX_TEXT_X, y: WX_COND_Y });

	feels = text_new(parent, FONT_REG_15, C_TXT_DIM, '');
	feels.obj.set({ x: WX_TEXT_X, y: WX_FEELS_Y });

	sky = icon_new(parent, IMAGE_WX_CLOUD_LG, C_SKY);
	sky.set({ x: WX_SKY_X, y: WX_SKY_Y });

	let rule = box_new(parent, C_RULE, 0);

	rule.set({ x: RULE_PAD, y: WX_RULE_Y, w: W - 2 * RULE_PAD, h: SEP_H });

	for (let i = 0; i < WX_DAYS; i++)
		push(columns, column_build(parent, i));
}

return {
	name: 'weather',
	needs: [ 'weather' ],
	requires_option: [ 'latitude', 'longitude' ],
	build: page_build,
	enter: page_update,
	update: page_update
};
