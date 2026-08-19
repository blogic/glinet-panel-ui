'use strict';

import { LIST_H_SUB } from '../lib/theme.uc';
import { list_new } from '../lib/widget.uc';
import { key_of } from '../lib/layout.uc';
import { rows_new } from '../lib/component/rows.uc';

const SUFFIX = [ '', '6', '_4', '_6' ];

const HOUR = 3600;
const DAY = 24 * HOUR;

let state, activity;
let list;
let base;

function objects_of() {
	let out = [];

	for (let suffix in SUFFIX) {
		let entry = state.iface[base + suffix];

		if (entry)
			push(out, entry);
	}

	return out;
}

function uptime_of(seconds) {
	if (!seconds)
		return null;

	if (seconds >= DAY)
		return sprintf('%dd %dh', int(seconds / DAY),
			       int((seconds % DAY) / HOUR));

	return sprintf('%dh %dm', int(seconds / HOUR),
		       int((seconds % HOUR) / 60));
}

function v4_of(entries) {
	let out = [];

	for (let entry in entries)
		for (let addr in entry['ipv4-address'] ?? [])
			if (addr?.address)
				push(out, sprintf('%s/%d', addr.address, addr.mask));

	return sort(out, (a, b) => length(b) - length(a));
}

function v6_of(entries) {
	let out = [];

	for (let entry in entries) {
		for (let addr in entry['ipv6-address'] ?? [])
			if (addr?.address)
				push(out, sprintf('%s/%d', addr.address, addr.mask));

		for (let prefix in entry['ipv6-prefix-assignment'] ?? [])
			if (prefix?.['local-address']?.address)
				push(out, sprintf('%s/%d',
						  prefix['local-address'].address,
						  prefix.mask));
	}

	return sort(out, (a, b) => length(b) - length(a));
}

function rows_of() {
	let entries = objects_of();

	if (!length(entries))
		return [];

	let up = false;
	let uptime = 0;

	for (let entry in entries) {
		if (entry.up)
			up = true;

		if (entry.uptime > uptime)
			uptime = entry.uptime;
	}

	let out = [];
	let since = uptime_of(uptime);

	push(out, [ 'flat', 'Status',
		    up ? (since ? sprintf('Up · %s', since) : 'Up') : 'Down' ]);

	let v4 = v4_of(entries);
	let v6 = v6_of(entries);
	let dns = [];

	for (let entry in entries)
		for (let server in entry['dns-server'] ?? [])
			push(dns, server);

	if (length(v4))
		push(out, [ 'stacked', 'IPv4', join('\n', v4) ]);

	if (length(v6))
		push(out, [ 'stacked', 'IPv6', join('\n', v6) ]);

	if (length(dns))
		push(out, [ 'stacked', 'DNS', join('\n', dns) ]);

	return out;
}

function key_row(row) {
	return join('|', row);
}

/* Caption above value: the longest IPv6 address is 263 px of the 300 available
   and cannot share a line with its caption. */
function row_of(row) {
	if (row[0] == 'stacked')
		return { stacked: true, caption: row[1], value: row[2] };

	return { label: row[1], value: row[2] };
}

function page_update(source) {
	let rows = rows_of();

	list.set(key_of(rows, key_row), rows, row_of);
}

function page_build(parent, ctx) {
	state = ctx.state;
	activity = ctx.activity;
	base = ctx.params?.name ?? 'wan';

	let scroll = list_new(parent, { title: uc(base), indented: true,
					height: LIST_H_SUB, activity });

	list = rows_new(scroll, { empty: 'Not available', activity });

	page_update(null);
}

return {
	needs: [ 'interfaces' ],
	build: page_build,
	update: page_update
};
