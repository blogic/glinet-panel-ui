'use strict';

import * as lv from 'lv';
import { LIST_H_SUB } from '../lib/theme.uc';
import { list_new, text_set } from '../lib/widget.uc';
import { rows_new } from '../lib/component/rows.uc';
import { ssid_enable } from '../lib/wireless.uc';
import { FONT_TNUM_12, FONT_REG_13, IMAGE_EYE,
	 IMAGE_EYE_OFF } from '../lib/assets.uc';

const DOTS = '••••••••';

const OPA_DEPENDENT = 102;

/* The dependent rows stay in place when the switch goes off, dimmed: removing
   them would reflow the page under the finger that just turned it off. */
const ROW_ENABLED	= 0;
const ROW_QR		= 1;
const ROW_PASSWORD	= 2;

let state, activity, open, back;
let list, password;
let name, revealed;

function net_of() {
	for (let entry in state.networks)
		if (entry.ssid == name)
			return entry;

	return null;
}

function dependents_dim(on) {
	for (let i = ROW_QR; i <= ROW_PASSWORD; i++)
		list.rows[i]?.obj.style({ opa: on ? lv.OPA_COVER
						  : OPA_DEPENDENT });
}

function key_now() {
	let net = net_of();

	return sprintf('%s|%s|%s', net?.up ? '1' : '0', net?.key ?? '',
		       revealed ? '1' : '0');
}

function reveal_toggle() {
	let net = net_of();

	activity();

	if (!net?.up)
		return;

	revealed = !revealed;
	/* The key it was built under, so the next update does not rebuild the
	   row this handler is part of. */
	list.key = key_now();

	text_set(password.value, revealed ? (net.key ?? '') : DOTS);
	password.value.obj.style({ text_font: revealed ? FONT_TNUM_12
						       : FONT_REG_13 });
	password.eye.src(revealed ? IMAGE_EYE_OFF : IMAGE_EYE);
}

function row_of(row) {
	let net = row.net;

	if (row.kind == ROW_ENABLED)
		return {
			label: 'Enabled',
			accessory: 'switch',
			on: net.up,
			on_toggle: function(value) {
				activity();
				dependents_dim(value);
				ssid_enable(net, value);
			}
		};

	if (row.kind == ROW_QR)
		return {
			label: 'Show QR code',
			accessory: 'chevron',
			on_tap: function() {
				activity();

				if (!net.up)
					return;

				open('qr', { ssid: net.ssid });
			}
		};

	return {
		label: 'Password',
		value: revealed ? (net.key ?? '') : DOTS,
		value_font: revealed ? FONT_TNUM_12 : FONT_REG_13,
		accessory: 'eye',
		revealed,
		on_reveal: reveal_toggle
	};
}

function rows_of() {
	let net = net_of();

	if (!net)
		return [];

	return [ { kind: ROW_ENABLED, net }, { kind: ROW_QR, net },
		 { kind: ROW_PASSWORD, net } ];
}

function page_update(source) {
	let rows = rows_of();

	if (!list.set(key_now(), rows, row_of))
		return;

	if (!length(rows))
		return;

	password = list.rows[ROW_PASSWORD];
	dependents_dim(rows[0].net.up);
}

function page_build(parent, ctx) {
	state = ctx.state;
	activity = ctx.activity;
	open = ctx.open;
	back = ctx.back;
	name = ctx.params?.ssid;

	let scroll = list_new(parent, { title: name ?? 'Wi-Fi', indented: true,
					height: LIST_H_SUB, activity });

	list = rows_new(scroll, { empty: '', activity });

	page_update(null);
}

return {
	needs: [ 'wireless' ],
	build: page_build,
	update: page_update
};
