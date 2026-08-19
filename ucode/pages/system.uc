'use strict';

import { C_RULE, W, SEP_H, RULE_PAD } from '../lib/theme.uc';
import { box_new, header_new } from '../lib/widget.uc';
import { body_new, cell_set } from '../lib/layout.uc';
import { gauge_new } from '../lib/component/gauge.uc';

/* Read over 30 to 90, so a cold chip draws a short arc rather than an empty
   ring. The colour still comes from the raw reading. */
const TEMP_LOW	= 30;
const TEMP_HIGH	= 90;

const PER_CENT	= '%';
const DEGREE	= uchr(0xb0);

let gauges = {};
let state;

function gauge_at(grid, col, row, opts) {
	return cell_set(gauge_new(grid, { ...opts,
					  side: col ? 'right' : 'left' }),
			col, row);
}

function page_build(parent, ctx) {
	state = ctx.state;

	header_new(parent, 'System', false, null);

	let grid = body_new(parent, { cols: [ '1fr', '1fr' ],
				      rows: [ '1fr', 'content', '1fr' ] });

	gauges.cpu = gauge_at(grid, 0, 0, { caption: 'CPU', unit: PER_CENT });
	gauges.temp = gauge_at(grid, 1, 0, { caption: 'Temp', unit: DEGREE,
					     low: TEMP_LOW, high: TEMP_HIGH });

	let rule = box_new(grid, C_RULE, 0);

	rule.set({ w: W - 2 * RULE_PAD, h: SEP_H });
	cell_set(rule, 0, 1, { span_x: 2, align_x: 'centre',
			       align_y: 'centre' });

	gauges.mem = gauge_at(grid, 0, 2, { caption: 'RAM', unit: PER_CENT });
	gauges.flash = gauge_at(grid, 1, 2, { caption: 'Flash',
					      unit: PER_CENT });
}

function page_update(source) {
	gauges.cpu.set(state.cpu);
	gauges.mem.set(state.mem);
	gauges.flash.set(state.flash);
	/* null, not zero: a board with no thermal zone says nothing. */
	gauges.temp.set(state.temp);
}

return {
	needs: [ 'cpu', 'sysinfo', 'temp' ],
	build: page_build,
	enter: page_update,
	update: page_update
};
