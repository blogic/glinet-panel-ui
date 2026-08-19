'use strict';

import { ROW_H_ROOT } from '../lib/theme.uc';
import { list_new, text_set } from '../lib/widget.uc';
import { key_of } from '../lib/layout.uc';
import { rows_new } from '../lib/component/rows.uc';

let state, activity, open;
let list;

function detail_of(net) {
	if (!net.up)
		return 'Off';

	let clients = net.clients == 1 ? '1 client'
				       : sprintf('%d clients', net.clients);

	return sprintf('%s · %s', net.security, clients);
}

/* No client count: it changes at tick rate, and a rebuild would tear the rows
   down under the finger. */
function key_net(net) {
	return sprintf('%s|%s', net.ssid, net.up ? '1' : '0');
}

function tap_handler(ssid) {
	return function() {
		activity();
		open('ssid', { ssid });
	};
}

function row_of(net) {
	return {
		dot: net.up,
		label: net.ssid,
		secondary: detail_of(net),
		accessory: 'chevron',
		on_tap: tap_handler(net.ssid)
	};
}

function page_update(source) {
	let nets = state.networks;

	if (list.set(key_of(nets, key_net), nets, row_of))
		return;

	for (let i = 0; i < length(list.rows); i++)
		text_set(list.rows[i].secondary, detail_of(nets[i]));
}

function page_build(parent, ctx) {
	state = ctx.state;
	activity = ctx.activity;
	open = ctx.open;

	let scroll = list_new(parent, { title: 'Wi-Fi', activity });

	list = rows_new(scroll, { empty: 'No networks', h: ROW_H_ROOT,
				  large: true, activity });
}

return {
	needs: [ 'wireless' ],
	build: page_build,
	enter: page_update,
	update: page_update
};
