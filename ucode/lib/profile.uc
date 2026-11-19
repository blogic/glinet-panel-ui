// SPDX-License-Identifier: GPL-2.0-only
'use strict';

import { readfile } from 'fs';
import { FONT_LIGHT_45, FONT_SEMI_15, FONT_THIN_112 } from 'lvgl.assets';

const landscape = {
	theme: { width: 320, height: 240 },
	boot: { logo: true },
	background: true,
	traffic_height: 68,
	ports: { large_limit: 8, large_columns: 4, small_columns: 5 },
	gauge: { direction: 'row', gap: 10, edge: 20 },
	lock: {
		font: FONT_THIN_112, date_gap: 32, rate_gap: 34, short_date: false,
		weather_below_clock: false, rate_row_gap: null
	},
	weather: {
		temp_x: 16, temp_y: 59, text_x: 87, condition_y: 54, feels_y: 79,
		rule_y: 109, days: 5, column_width: 61,
		day_y: 117, icon_y: 143, high_y: 177, low_y: 202
	}
};

const portrait = {
	theme: {
		width: 172, height: 320, dot_gap: 9, dialog_inset: 8,
		header_font: FONT_SEMI_15, header_indent: 38,
		title_inset: 44, subpage_title_inset: 10, tally_width: 22
	},
	boot: { title: 'OpenWrt', subtitle: 'GL-VB7200BE' },
	background: false,
	traffic_height: 90,
	ports: { large_limit: 4, large_columns: 2, small_columns: 3 },
	gauge: { direction: 'column', gap: 4, edge: 0 },
	lock: {
		font: FONT_LIGHT_45, date_gap: 20, rate_gap: 68, short_date: true,
		weather_below_clock: true, weather_inset: 9,
		weather_gap: 10, weather_icon_offset: 4, rate_row_gap: 5
	},
	weather: {
		temp_x: 12, temp_y: 56, text_x: 12, condition_y: 112, feels_y: 136,
		text_width: 148, rule_y: 169, days: 3, column_width: 52,
		day_y: 193, icon_y: 217, high_y: 245, low_y: 269
	}
};

const devices = {
	'glinet,gl-be10000': landscape,
	'glinet,gl-be10000-ubootmod': landscape,
	'glinet,gl-be14000': landscape,
	'glinet,gl-vb7200be': portrait
};

function select_profile(compatible) {
	/* The device tree lists the most specific match first. */
	for (let name in split(compatible ?? '', '\x00'))
		if (devices[name])
			return devices[name];

	return landscape;
}

export const profile = select_profile(readfile('/proc/device-tree/compatible'));

/* Both entry points load the profile before evaluating lvgl.theme. */
const theme_options = require('lvgl.theme_options');

for (let key, value in profile.theme)
	theme_options[key] = value;
