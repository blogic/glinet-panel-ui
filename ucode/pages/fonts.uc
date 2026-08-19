'use strict';

import * as lv from 'lv';
import { C_TXT, C_RULE, CARD_W, CARD_PAD, SEP_H } from '../lib/theme.uc';
import { card_new, label_new, box_new, scroll_new } from '../lib/widget.uc';
import { flow_set, flow_new, grow_set } from '../lib/layout.uc';
import { FONT_TNUM_10, FONT_SEMI_10, FONT_REG_11, FONT_TNUM_12, FONT_REG_13,
	 FONT_REG_15, FONT_SEMI_15, FONT_REG_20, FONT_SEMI_21, FONT_REG_26,
	 FONT_LIGHT_27, FONT_LIGHT_45, FONT_THIN_112 } from '../lib/assets.uc';

const CARD_Y	= 0;
const CARD_H	= 214;

const CONTENT_Y	= CARD_PAD;
const CONTENT_H	= CARD_H - 2 * CARD_PAD;

const ROW_PAD	= 6;
const NAME_W	= 96;

/*
 * Ordered by size, one row per face. The sample is the same word wherever it
 * can be drawn: the three display cuts carry digits and a separator only, which
 * is what makes them cost a kilobyte where a full ASCII face of the same size
 * costs ten.
 *
 * A tabular cut has its digits remapped onto a single advance, so its sample is
 * an address: that is the whole reason it exists.
 */
const ROWS = [
	[ FONT_TNUM_10,		'192.168.8.1/24',	'10 tabular' ],
	[ FONT_SEMI_10,		'OpenWrt',		'10 semibold' ],
	[ FONT_REG_11,		'OpenWrt',		'11 regular' ],
	[ FONT_TNUM_12,		'192.168.8.1/24',	'12 tabular' ],
	[ FONT_REG_13,		'OpenWrt',		'13 regular' ],
	[ FONT_REG_15,		'OpenWrt',		'15 regular' ],
	[ FONT_SEMI_15,		'OpenWrt',		'15 semibold' ],
	[ FONT_REG_20,		'OpenWrt',		'20 regular' ],
	[ FONT_SEMI_21,		'OpenWrt',		'21 semibold' ],
	[ FONT_REG_26,		'↓ 12.3 MB',		'26 regular' ],
	[ FONT_LIGHT_27,	'123.4',		'27 light' ],
	[ FONT_LIGHT_45,	'12:34',		'45 light' ],
	[ FONT_THIN_112,	'12:34',		'112 thin' ]
];

function row_build(column, font, sample, name) {
	let row = flow_new(column, { dir: 'row', cross: 'centre',
				     h: lv.font_line_height(font) + 2 * ROW_PAD });

	row.style({ pad_left: CARD_PAD, pad_right: CARD_PAD });

	grow_set(label_new(row, font, C_TXT, sample));

	let label = label_new(row, FONT_REG_11, C_TXT, name);

	label.set({ w: NAME_W });
	label.style({ text_align: lv.TEXT_ALIGN_RIGHT });
}

function page_build(parent, ctx) {
	let card = card_new(parent, CARD_Y, CARD_H);
	let area = scroll_new(card, 0, CONTENT_Y, CARD_W, CONTENT_H);

	area.on(lv.EVENT_PRESSED, ctx.activity);

	let column = flow_set(area, { dir: 'column', cross: 'centre' });

	for (let i = 0; i < length(ROWS); i++) {
		row_build(column, ROWS[i][0], ROWS[i][1], ROWS[i][2]);

		if (i + 1 >= length(ROWS))
			continue;

		box_new(column, C_RULE, 0).set({ w: CARD_W - 2 * CARD_PAD,
						h: SEP_H });
	}
}

return {
	needs: [],
	build: page_build
};
