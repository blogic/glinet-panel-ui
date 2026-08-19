'use strict';

import * as lv from 'lv';
import { C_TXT, C_TXT_DIM, C_IDLE, W, H, DOT_SIZE,
	 DOT_GAP } from '../lib/theme.uc';
import { label_new, header_new, HEAD_H } from '../lib/widget.uc';
import { flow_new, cells_at, span, centre } from '../lib/layout.uc';
import { qrplate_new, CAP_GAP } from '../lib/component/qrplate.uc';
import { qr_payload } from '../lib/qr.uc';
import { FONT_REG_11, FONT_REG_13 } from '../lib/assets.uc';

const PAGE_H	= H - HEAD_H;

const COL_X	= W - 7 - DOT_SIZE;

let state, activity;
let parent_obj, pager, dots;
let shown;

function codes_of() {
	let out = [];

	for (let net in state.networks)
		if (net.up)
			push(out, net);

	return out;
}

function signature(list) {
	let parts = [];

	for (let net in list)
		push(parts, qr_payload(net));

	return join('\n', parts);
}

function dir_for(pos, count) {
	if (count < 2)
		return lv.DIR_NONE;
	if (pos == 0)
		return lv.DIR_BOTTOM;
	if (pos == count - 1)
		return lv.DIR_TOP;

	return lv.DIR_VER;
}

function dots_refresh() {
	let now = pager?.tile_active()?.row ?? 0;

	for (let i = 0; i < length(dots); i++)
		dots[i].style({ bg_color: i == now ? C_TXT_DIM : C_IDLE });
}

function code_build(tile, net) {
	let column = flow_new(tile, { dir: 'column', main: 'centre',
				      cross: 'centre', gap: CAP_GAP });

	qrplate_new(column).set(qr_payload(net));

	let caption = label_new(column, FONT_REG_11, C_TXT_DIM,
				sprintf('%s · %s', net.ssid, net.security));

	caption.set({ w: W });
	caption.style({ text_align: lv.TEXT_ALIGN_CENTER });
}

function view_build(list) {
	if (pager) {
		pager.delete();
		pager = null;
	}

	dots = [];

	let count = length(list);

	if (!count) {
		pager = label_new(parent_obj, FONT_REG_13, C_TXT,
				  'No networks');
		pager.set({ x: 0, y: HEAD_H + 20, w: W });
		pager.style({ text_align: lv.TEXT_ALIGN_CENTER });

		return;
	}

	pager = lv.tileview(parent_obj);

	pager.set({ x: 0, y: HEAD_H, w: W, h: PAGE_H });
	pager.style({ bg_opa: lv.OPA_TRANSP, border_width: 0, pad_all: 0 });
	pager.scrollbar(lv.SCROLLBAR_OFF);
	pager.on(lv.EVENT_VALUE_CHANGED, function() {
		activity();
		dots_refresh();
	});

	for (let i = 0; i < count; i++) {
		let tile = pager.tile_add(0, i, dir_for(i, count));

		tile.style({ bg_opa: lv.OPA_TRANSP, border_width: 0,
			     pad_all: 0 });
		tile.scrollbar(lv.SCROLLBAR_OFF);
		tile.scrollable(false);
		tile.on(lv.EVENT_PRESSED, activity);

		code_build(tile, list[i]);
	}

	if (count < 2)
		return;

	let at = cells_at(centre(H, span(DOT_SIZE, count, DOT_GAP - DOT_SIZE)),
			  DOT_SIZE, count, DOT_GAP - DOT_SIZE);

	for (let i = 0; i < count; i++) {
		let dot = lv.obj(parent_obj);

		dot.set({ x: COL_X, y: at[i], w: DOT_SIZE, h: DOT_SIZE });
		dot.style({ bg_color: C_IDLE, bg_opa: lv.OPA_COVER,
			    radius: DOT_SIZE, border_width: 0, pad_all: 0 });
		dot.clickable(false);
		dot.scrollable(false);

		push(dots, dot);
	}

	dots_refresh();
}

function page_update(source) {
	let list = codes_of();
	let sig = signature(list);

	if (shown == sig)
		return;

	shown = sig;
	view_build(list);
}

function page_build(parent, ctx) {
	state = ctx.state;
	activity = ctx.activity;
	parent_obj = parent;

	header_new(parent, 'QR codes', false, null);
}

return {
	needs: [ 'wireless' ],
	build: page_build,
	enter: page_update,
	update: page_update
};
