'use strict';

import * as lv from 'lv';
import { FONT_REG_26 } from '../lib/assets.uc';
import { C_TXT, C_SERIES, C_SERIES_ALT, C_RULE, W, SEP_H,
	 RULE_PAD } from '../lib/theme.uc';
import { text_new, text_set, bars_new, bar_scaled, box_new,
	 header_new } from '../lib/widget.uc';
import { body_new, flow_new, cell_set } from '../lib/layout.uc';
import { rate_fmt } from '../lib/rate.uc';

const PAD	= 12;
const BARS_W	= W - 2 * PAD;

/* Also the divisor in bar_scaled(), which gives every sample at least two
   pixels so a quiet link looks alive rather than broken. Changing it changes
   the data mapping and not only the geometry, so the chart is given this
   height rather than taking one from the layout. */
const BARS_H	= 68;

const DOWN	= '↓';
const UP	= '↑';

let down, up;
let bucket;
let state;

function meter_new(grid, row, colour, arrow, points) {
	let cell = flow_new(grid, { dir: 'column', main: 'centre',
				    cross: 'centre' });

	cell_set(cell, 0, row);

	let bars = bars_new(cell, colour, 0, 0, BARS_W, BARS_H, points);

	/* One label, so the arrow, the reading and the unit stay together as the
	   number gains a digit. */
	let label = text_new(bars, FONT_REG_26, C_TXT, '');

	label.obj.set({ align: lv.ALIGN_CENTER, w: BARS_W });
	label.obj.style({ text_align: lv.TEXT_ALIGN_CENTER });

	return { label, bars, arrow };
}

function meter_set(meter, bytes) {
	let rate = rate_fmt(bytes);

	text_set(meter.label, sprintf('%s %s %s', meter.arrow, rate.value,
				      rate.unit));
}

function series_reload() {
	down.bars.points(0, map(state.rx, v => bar_scaled(v, bucket, BARS_H)));
	up.bars.points(0, map(state.tx, v => bar_scaled(v, bucket, BARS_H)));
}

function range_sync() {
	if (bucket == state.bucket)
		return false;

	bucket = state.bucket;
	series_reload();

	return true;
}

function page_build(parent, ctx) {
	state = ctx.state;

	header_new(parent, 'Traffic', false, null);

	let grid = body_new(parent, { cols: [ '1fr' ],
				      rows: [ '1fr', 'content', '1fr' ] });

	/* The two blues read as two of the same kind of thing, which they are. */
	down = meter_new(grid, 0, C_SERIES, DOWN, ctx.points);

	let rule = box_new(grid, C_RULE, 0);

	rule.set({ w: W - 2 * RULE_PAD, h: SEP_H });
	cell_set(rule, 0, 1, { align_x: 'centre', align_y: 'centre' });

	up = meter_new(grid, 2, C_SERIES_ALT, UP, ctx.points);
}

function page_enter() {
	bucket = state.bucket;
	series_reload();

	meter_set(down, state.rx[-1] ?? 0);
	meter_set(up, state.tx[-1] ?? 0);
}

function page_update(source) {
	if (!range_sync()) {
		down.bars.push(0, bar_scaled(state.rx[-1] ?? 0, bucket, BARS_H));
		up.bars.push(0, bar_scaled(state.tx[-1] ?? 0, bucket, BARS_H));
	}

	meter_set(down, state.rx[-1] ?? 0);
	meter_set(up, state.tx[-1] ?? 0);
}

return {
	needs: [ 'wan' ],
	build: page_build,
	enter: page_enter,
	update: page_update
};
