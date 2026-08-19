'use strict';

import { ROW_H_ROOT } from '../lib/theme.uc';
import { list_new } from '../lib/widget.uc';
import { key_of } from '../lib/layout.uc';
import { rows_new } from '../lib/component/rows.uc';

const SUFFIX = [ '6', '_4', '_6' ];

let state, activity, open;
let list;

function is_variant(name) {
	for (let suffix in SUFFIX) {
		let base = substr(name, 0, length(name) - length(suffix));

		if (base && substr(name, length(base)) == suffix &&
		    state.iface[base])
			return true;
	}

	return false;
}

function address_of(entry) {
	let addr = entry?.['ipv4-address']?.[0];

	if (addr?.address)
		return sprintf('%s/%d', addr.address, addr.mask);

	return null;
}

function detail_of(entry) {
	return address_of(entry) ?? (entry.up ? 'Up' : 'Down');
}

function is_loopback(entry) {
	/* On the device, not the name: a uci section can be renamed, and lo is
	   what actually makes it the loopback. */
	return entry?.device == 'lo' || entry?.l3_device == 'lo';
}

function rows_of() {
	let out = [];

	for (let name, entry in state.iface) {
		if (is_variant(name))
			continue;

		if (is_loopback(entry))
			continue;

		push(out, { name, entry });
	}

	return out;
}

function key_row(row) {
	return sprintf('%s|%s|%s', row.name, detail_of(row.entry),
		       row.entry.up ? '1' : '0');
}

function tap_handler(name) {
	return function() {
		activity();
		open('interface', { name });
	};
}

function row_of(row) {
	return {
		dot: row.entry.up,
		label: uc(row.name),
		secondary: detail_of(row.entry),
		accessory: 'chevron',
		on_tap: tap_handler(row.name)
	};
}

function page_update(source) {
	let rows = rows_of();

	list.set(key_of(rows, key_row), rows, row_of);
}

function page_build(parent, ctx) {
	state = ctx.state;
	activity = ctx.activity;
	open = ctx.open;

	let scroll = list_new(parent, { title: 'Interfaces', activity });

	list = rows_new(scroll, { empty: 'No interfaces', h: ROW_H_ROOT,
				  large: true, activity });
}

return {
	needs: [ 'interfaces' ],
	build: page_build,
	enter: page_update,
	update: page_update
};
