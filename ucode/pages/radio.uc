'use strict';

import { C_WARN, ROW_H_ROOT } from '../lib/theme.uc';
import { list_new } from '../lib/widget.uc';
import { key_of } from '../lib/layout.uc';
import { rows_new } from '../lib/component/rows.uc';

const WIDTH = [ 20, 20, 40, 80, 80, 160, 5, 10, 1, 2, 4, 8, 16, 320 ];

const BAND_5	= 2500;
const BAND_6	= 5900;

const BAND_KEY	= { '2.4 GHz': '2g', '5 GHz': '5g', '6 GHz': '6g' };

let list;
let state;

function band_of(freq) {
	if (!freq)
		return null;

	if (freq < BAND_5)
		return '2.4 GHz';

	if (freq < BAND_6)
		return '5 GHz';

	return '6 GHz';
}

function channel_of(freq) {
	if (freq < BAND_5)
		/* 14 is 12 MHz above 13, not 5, so it is off the grid. */
		return freq == 2484 ? 14 : int((freq - 2407) / 5);

	if (freq < BAND_6)
		return int((freq - 5000) / 5);

	/* 6 GHz channel 2 sits below channel 1, off the grid the rest uses. */
	return freq == 5935 ? 2 : int((freq - 5950) / 5);
}

function radio_for(band) {
	let want = BAND_KEY[band];

	for (let name, radio in state.radios)
		if (radio?.config?.band == want)
			return radio;

	return null;
}

function iface_for(band) {
	for (let entry in state.wifi)
		if (band_of(entry.wiphy_freq) == band)
			return entry;

	return null;
}

function mode_of(radio) {
	let found = match(radio?.config?.htmode ?? '', /^([A-Z]+)/);

	return found ? found[1] : null;
}

function row_of(band) {
	let radio = radio_for(band);

	if (radio?.disabled)
		return { band, detail: 'Disabled', idle: true };

	let entry = iface_for(band);

	if (!entry?.ssid)
		return { band, detail: 'No SSID', idle: true };

	let mode = mode_of(radio);
	let width = WIDTH[entry.channel_width];
	let detail = sprintf('Channel %d', channel_of(entry.wiphy_freq));

	if (width)
		detail += sprintf(' / %d MHz', width);

	return {
		band,
		detail: mode ? detail + sprintf(' / %s', mode) : detail,
		idle: false
	};
}

function rows_of() {
	let seen = {};
	let rows = [];

	for (let freq in state.bands) {
		let band = band_of(freq);

		if (seen[band])
			continue;

		seen[band] = true;
		push(rows, row_of(band));
	}

	return rows;
}

function row_opts(row) {
	return {
		label: row.band,
		secondary: row.detail,
		secondary_colour: row.idle ? C_WARN : null
	};
}

function key_row(row) {
	return sprintf('%s|%s', row.band, row.detail);
}

function page_update(source) {
	let rows = rows_of();

	list.set(key_of(rows, key_row), rows, row_opts);
}

function page_build(parent, ctx) {
	state = ctx.state;

	let scroll = list_new(parent, { title: 'Radios',
					activity: ctx.activity });

	list = rows_new(scroll, { empty: 'No radios', h: ROW_H_ROOT,
				  large: true, activity: ctx.activity });
}

return {
	needs: [ 'wireless' ],
	build: page_build,
	enter: page_update,
	update: page_update
};
