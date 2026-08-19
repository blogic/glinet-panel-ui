'use strict';

import * as lv from 'lv';
import * as uloop from 'uloop';
import { FONT_LIGHT_27 } from '../lib/assets.uc';
import { C_TXT, C_RULE, C_SERIES, W, TRACK_SPACE } from '../lib/theme.uc';
import { card_new, text_new, text_set, box_new,
	 outline_new } from '../lib/widget.uc';
import { flow_new } from '../lib/layout.uc';

const CARD_Y	= 0;
const CARD_H	= 214;

/* The box the readout sits in, not a line height: FONT_LIGHT_27 stands 21. */
const READ_H	= 34;
const SEP_SIZE	= 8;
const SEP_GAP	= 8;
const HALF	= int(W / 2) - SEP_GAP - int(SEP_SIZE / 2);

const MARK	= 14;
const MARK_INSET = 6;
const SPOT	= 14;
const POLL_MS	= 50;

let read_x, read_y, spot, poll;

/* The point LVGL hands out, so it shows the device tree transform and nothing
   else. Touch a corner to work out which of swap and invert the panel needs. */
function touch_poll() {
	let point = lv.touch_point();

	if (!point)
		return;

	text_set(read_x, sprintf('%d', point.x));
	text_set(read_y, sprintf('%d', point.y));

	spot.hidden(!point.pressed);
	spot.set({ x: point.x - int(SPOT / 2), y: point.y - int(SPOT / 2) });
}

function marks_build(card) {
	let far_x = W - MARK - MARK_INSET;
	let far_y = CARD_H - MARK - MARK_INSET;
	let corner = [
		[ MARK_INSET, MARK_INSET ],
		[ far_x, MARK_INSET ],
		[ MARK_INSET, far_y ],
		[ far_x, far_y ]
	];

	for (let at in corner)
		outline_new(card, C_RULE).set({ x: at[0], y: at[1],
					       w: MARK, h: MARK });
}

function page_build(parent, ctx) {
	let card = card_new(parent, CARD_Y, CARD_H);

	let row = flow_new(card, { dir: 'row', main: 'centre', cross: 'centre',
				   gap: SEP_GAP });

	read_x = text_new(row, FONT_LIGHT_27, C_TXT, '0');
	read_x.obj.set({ w: HALF, h: READ_H });
	read_x.obj.style({ text_align: lv.TEXT_ALIGN_RIGHT,
			   text_letter_space: TRACK_SPACE });

	box_new(row, C_RULE, 0).set({ w: SEP_SIZE, h: SEP_SIZE });

	read_y = text_new(row, FONT_LIGHT_27, C_TXT, '0');
	read_y.obj.set({ w: HALF, h: READ_H });
	read_y.obj.style({ text_letter_space: TRACK_SPACE });

	marks_build(card);

	/* Off the tile, not the card: a child is clipped to its parent and the
	   card stops short of the dots. Written live, so outside any layout. */
	spot = box_new(parent, C_SERIES, SPOT);
	spot.set({ x: 0, y: 0, w: SPOT, h: SPOT });
	spot.hidden(true);

	poll = uloop.interval(0, touch_poll);
}

function page_enter() {
	poll.set(POLL_MS);
}

function page_leave() {
	poll.set(0);
	spot.hidden(true);
}

return {
	needs: [],
	build: page_build,
	enter: page_enter,
	leave: page_leave
};
