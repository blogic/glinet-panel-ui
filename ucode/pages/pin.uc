'use strict';

import * as lv from 'lv';
import * as uloop from 'uloop';
import { C_TXT, C_TXT_DIM, C_SURFACE, C_RAISED, C_ALERT, C_RULE, W, H, PIN_LEN,
	 PIN_PAD, PIN_TOP, PIN_BOTTOM, PIN_DOT, PIN_DOT_GAP,
	 PIN_KEY_GAP } from '../lib/theme.uc';
import { label_new, text_new, text_set, icon_new,
	 card_opacity } from '../lib/widget.uc';
import { grid_new, cell_set, cells_at, span, centre } from '../lib/layout.uc';
import { FONT_REG_20, FONT_REG_13, IMAGE_BACKSPACE } from '../lib/assets.uc';

const PROMPT_GAP = 9;
const PAD_GAP	= 10;

const DOT_Y	= PIN_TOP + lv.font_line_height(FONT_REG_13) + PROMPT_GAP;
/* The border is drawn inside the radius, so half the size leaves the corners
   square on an even width. */
const DOT_R	= int(PIN_DOT / 2) + 1;
const DOT_AT	= cells_at(centre(W, span(PIN_DOT, PIN_LEN, PIN_DOT_GAP)),
			   PIN_DOT, PIN_LEN, PIN_DOT_GAP);

const PAD_Y	= DOT_Y + PIN_DOT + PAD_GAP;
const PAD_H	= H - PIN_BOTTOM - PAD_Y;
const KEY_RADIUS = 8;

const SHAKE	= [ -4, 4, -3, 3, -2, 2, 0 ];
const SHAKE_MS	= 43;

const PROMPT	= 'Enter PIN';
const REFUSED	= 'Incorrect PIN';

let expected, unlock, activity;
let prompt, dots = [];
let entered = '';
let shake_step, shake_timer;

function dot_style(dot, state) {
	if (state == 'filled') {
		dot.style({ bg_color: C_TXT, bg_opa: lv.OPA_COVER,
			    border_color: C_TXT });

		return;
	}

	dot.style({ bg_opa: lv.OPA_TRANSP,
		    border_color: state == 'error' ? C_ALERT : C_RULE });
}

function dots_refresh(state) {
	for (let i = 0; i < PIN_LEN; i++)
		dot_style(dots[i], state ?? (i < length(entered) ? 'filled'
								: 'empty'));
}

function shake_step_run() {
	if (shake_step >= length(SHAKE)) {
		entered = '';
		dots_refresh();

		return;
	}

	let dx = SHAKE[shake_step++];

	for (let i = 0; i < PIN_LEN; i++)
		dots[i].set({ x: DOT_AT[i] + dx });

	shake_timer.set(SHAKE_MS);
}

function refuse() {
	text_set(prompt, REFUSED);
	prompt.obj.style({ text_color: C_ALERT });
	dots_refresh('error');

	shake_step = 0;
	shake_timer.set(SHAKE_MS);
}

function digit_add(digit) {
	if (prompt.last != PROMPT) {
		text_set(prompt, PROMPT);
		prompt.obj.style({ text_color: C_TXT });
	}

	if (length(entered) >= PIN_LEN)
		return;

	entered += digit;
	dots_refresh();

	if (length(entered) < PIN_LEN)
		return;

	if (entered == expected) {
		entered = '';
		unlock();

		return;
	}

	refuse();
}

function digit_clear(all) {
	if (all)
		entered = '';
	else if (length(entered))
		entered = substr(entered, 0, length(entered) - 1);

	dots_refresh();
}

function key_handler(digit) {
	return function() {
		digit_add(digit);
	};
}

function key_new(pad, col, row, digit, fn) {
	let key = lv.obj(pad);

	cell_set(key, col, row);
	/* A key is a fill like any other, so it takes the card opacity: the
	   background is drawn behind this screen too. */
	key.style({ bg_color: C_SURFACE,
		    bg_opa: digit != null ? card_opacity() : lv.OPA_TRANSP,
		    radius: KEY_RADIUS, border_width: 0, pad_all: 0 });

	if (digit != null)
		key.style({ bg_color: C_RAISED },
			  lv.PART_MAIN | lv.STATE_PRESSED);

	key.clickable(true);
	key.scrollable(false);

	if (digit != null)
		label_new(key, FONT_REG_20, C_TXT, digit)
			.set({ align: lv.ALIGN_CENTER });
	else
		icon_new(key, IMAGE_BACKSPACE, C_TXT_DIM)
			.set({ align: lv.ALIGN_CENTER });

	key.on(lv.EVENT_PRESSED, activity);
	key.on(lv.EVENT_CLICKED, fn);

	return key;
}

function page_build(parent, ctx) {
	expected = ctx.pin;
	unlock = ctx.unlock;
	activity = ctx.activity;

	prompt = text_new(parent, FONT_REG_13, C_TXT, PROMPT);
	prompt.obj.set({ x: 0, y: PIN_TOP, w: W });
	prompt.obj.style({ text_align: lv.TEXT_ALIGN_CENTER });

	/* Outside any layout: the shake rewrites their x every 43 ms. */
	for (let i = 0; i < PIN_LEN; i++) {
		let dot = lv.obj(parent);

		dot.set({ x: DOT_AT[i], y: DOT_Y, w: PIN_DOT, h: PIN_DOT });
		dot.style({ bg_opa: lv.OPA_TRANSP, border_width: 1,
			    border_color: C_RULE, radius: DOT_R, pad_all: 0 });
		dot.clickable(false);
		dot.scrollable(false);

		push(dots, dot);
	}

	let pad = grid_new(parent, { cols: [ '1fr', '1fr', '1fr' ],
				     rows: [ '1fr', '1fr', '1fr', '1fr' ],
				     gap_x: PIN_KEY_GAP, gap_y: PIN_KEY_GAP,
				     x: PIN_PAD, y: PAD_Y,
				     w: W - 2 * PIN_PAD, h: PAD_H });

	for (let i = 1; i <= 9; i++)
		key_new(pad, (i - 1) % 3, int((i - 1) / 3),
			sprintf('%d', i), key_handler(sprintf('%d', i)));

	key_new(pad, 1, 3, '0', key_handler('0'));

	let back = key_new(pad, 2, 3, null, function() {
		digit_clear(false);
	});

	back.on(lv.EVENT_LONG_PRESSED, function() {
		digit_clear(true);
	});

	shake_timer = uloop.timer(-1, shake_step_run);
}

function page_enter() {
	entered = '';
	text_set(prompt, PROMPT);
	prompt.obj.style({ text_color: C_TXT });
	dots_refresh();
}

return {
	needs: [],
	build: page_build,
	enter: page_enter
};
