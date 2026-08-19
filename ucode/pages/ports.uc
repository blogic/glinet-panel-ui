'use strict';

import * as lv from 'lv';
import { C_TXT, C_TXT_DIM, C_OK, C_DOWN, W } from '../lib/theme.uc';
import { label_new, icon_new, header_new } from '../lib/widget.uc';
import { body_new, flow_new, pct } from '../lib/layout.uc';
import { FONT_REG_15, FONT_SEMI_10, FONT_REG_11, FONT_REG_13, IMAGE_CAGE_LG,
	 IMAGE_CAGE_SM, IMAGE_JACK_LG, IMAGE_JACK_SM } from '../lib/assets.uc';

const PAD	= 10;
const GAP_X	= 6;
const GAP_Y	= 7;
const LABEL_GAP	= 2;

const LARGE_MAX	= 8;
const LARGE = {
	per_row: 4, jack: IMAGE_JACK_LG, cage: IMAGE_CAGE_LG,
	icon_h: 46, name: FONT_REG_15, speed: FONT_REG_13
};
const SMALL = {
	per_row: 5, jack: IMAGE_JACK_SM, cage: IMAGE_CAGE_SM,
	icon_h: 23, name: FONT_SEMI_10, speed: FONT_REG_11
};

function tier_height(tier) {
	return tier.icon_h + LABEL_GAP + lv.font_line_height(tier.name) +
	       LABEL_GAP + lv.font_line_height(tier.speed);
}

let state, activity, open;
let parent_obj, holder;
let shown;

function speed_of(port) {
	if (!port.up || !port.speed)
		return '—';

	if (port.speed >= 1000) {
		let gig = port.speed / 1000.0;

		return gig == int(gig) ? sprintf('%dG', int(gig))
				       : sprintf('%.1fG', gig);
	}

	return sprintf('%dM', port.speed);
}

function signature(list) {
	let parts = [];

	for (let port in list)
		push(parts, sprintf('%s|%s|%s', port.name, speed_of(port),
				    port.up ? '1' : '0'));

	return join('\n', parts);
}

function tap_handler(device) {
	return function() {
		activity();
		open('port', { device });
	};
}

function rows_split(count, per_row) {
	let rows = int((count + per_row - 1) / per_row);
	let base = int(count / rows);
	let extra = count % rows;
	let out = [];

	for (let i = 0; i < rows; i++)
		push(out, base + (i < extra ? 1 : 0));

	return out;
}

function icon_for(port, tier) {
	return index(lc(port.name), 'sfp') >= 0 ? tier.cage : tier.jack;
}

function tile_build(row, port, tw, th, tier) {
	let tile = flow_new(row, { dir: 'column', cross: 'centre',
				   gap: LABEL_GAP, w: tw, h: th });

	tile.clickable(true);
	tile.on(lv.EVENT_PRESSED, activity);
	tile.on(lv.EVENT_CLICKED, tap_handler(port.device));

	icon_new(tile, icon_for(port, tier), port.up ? C_OK : C_DOWN);

	let name = label_new(tile, tier.name, port.up ? C_TXT : C_TXT_DIM,
			     port.name);

	name.set({ w: tw });
	name.style({ text_align: lv.TEXT_ALIGN_CENTER });

	let speed = label_new(tile, tier.speed, C_TXT_DIM, speed_of(port));

	speed.set({ w: tw });
	speed.style({ text_align: lv.TEXT_ALIGN_CENTER });
}

function view_build(list) {
	if (holder) {
		holder.delete();
		holder = null;
	}

	let count = length(list);

	if (!count)
		return;

	let tier = count <= LARGE_MAX ? LARGE : SMALL;
	/* Remainder on the earlier rows, which flex wrap cannot express. */
	let split = rows_split(count, tier.per_row);
	let tw = int((W - 2 * PAD - (tier.per_row - 1) * GAP_X) / tier.per_row);
	let th = tier_height(tier);

	holder = body_new(parent_obj, { dir: 'column', main: 'centre',
					cross: 'centre', gap: GAP_Y });

	let taken = 0;

	for (let row = 0; row < length(split); row++) {
		let wide = split[row];
		let line = flow_new(holder, { dir: 'row', main: 'centre',
					      gap: GAP_X, w: pct(100), h: th });

		for (let col = 0; col < wide; col++)
			tile_build(line, list[taken + col], tw, th, tier);

		taken += wide;
	}
}

function page_update(source) {
	let sig = signature(state.ports);

	if (shown == sig)
		return;

	shown = sig;
	view_build(state.ports);
}

function page_build(parent, ctx) {
	state = ctx.state;
	activity = ctx.activity;
	open = ctx.open;
	parent_obj = parent;

	header_new(parent, 'Ports', false, null);
}

return {
	needs: [ 'ports' ],
	build: page_build,
	enter: page_update,
	update: page_update
};
