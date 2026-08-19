'use strict';

import * as lv from 'lv';
import { C_RAISED, C_IDLE, C_DOWN, C_RULE, C_TXT_DIM, C_FILL, C_TXT, C_SERIES,
	 C_SERIES_ALT, C_ACTION, C_OK, C_WARN, C_ALERT, C_SKY, CARD_W,
	 CARD_PAD, SEP_H } from '../lib/theme.uc';
import { card_new, label_new, box_new, scroll_new } from '../lib/widget.uc';
import { flow_new, flow_set, grow_set } from '../lib/layout.uc';
import { FONT_REG_13 } from '../lib/assets.uc';

const CARD_Y	= 0;
const CARD_H	= 214;

const CONTENT_Y	= CARD_PAD;
const CONTENT_H	= CARD_H - 2 * CARD_PAD;

const ROW_H	= 26;
const SWATCH_W	= 30;
const SWATCH_H	= 16;
const SWATCH_R	= 3;
const SWATCH_GAP = 10;
const HEX_W	= 60;

const SWATCHES = [
	[ C_RAISED,	'Raised' ],
	[ C_IDLE,	'Idle' ],
	[ C_DOWN,	'Down' ],
	[ C_RULE,	'Rule' ],
	[ C_TXT_DIM,	'Text dim' ],
	[ C_FILL,	'Fill' ],
	[ C_TXT,	'Text' ],
	[ C_SERIES,	'Series' ],
	[ C_SERIES_ALT,	'Series alt' ],
	[ C_ACTION,	'Action' ],
	[ C_OK,		'OK' ],
	[ C_WARN,	'Warn' ],
	[ C_ALERT,	'Alert' ],
	[ C_SKY,	'Sky' ]
];

/* Each name is drawn in its own colour as well as swatched, because the
   question is whether it reads as text on this glass and not what it looks
   like as a block. The hex stays white: it is a label, not a specimen. */
function row_build(column, colour, name) {
	let row = flow_new(column, { dir: 'row', cross: 'centre',
				     gap: SWATCH_GAP, h: ROW_H });

	row.style({ pad_left: CARD_PAD, pad_right: CARD_PAD });

	box_new(row, colour, SWATCH_R).set({ w: SWATCH_W, h: SWATCH_H });

	grow_set(label_new(row, FONT_REG_13, colour, name));

	let hex = label_new(row, FONT_REG_13, C_TXT, sprintf('%06x', colour));

	hex.set({ w: HEX_W });
	hex.style({ text_align: lv.TEXT_ALIGN_RIGHT });
}

function page_build(parent, ctx) {
	let card = card_new(parent, CARD_Y, CARD_H);
	let area = scroll_new(card, 0, CONTENT_Y, CARD_W, CONTENT_H);

	area.on(lv.EVENT_PRESSED, ctx.activity);

	let column = flow_set(area, { dir: 'column', cross: 'centre' });

	for (let i = 0; i < length(SWATCHES); i++) {
		row_build(column, SWATCHES[i][0], SWATCHES[i][1]);

		if (i + 1 >= length(SWATCHES))
			continue;

		box_new(column, C_RULE, 0).set({ w: CARD_W - 2 * CARD_PAD,
						h: SEP_H });
	}
}

return {
	needs: [],
	build: page_build
};
