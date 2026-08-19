'use strict';

import { C_OK, C_TXT_DIM, LIST_H_SUB } from '../lib/theme.uc';
import { list_new } from '../lib/widget.uc';
import { key_of } from '../lib/layout.uc';
import { rows_new } from '../lib/component/rows.uc';

const DUPLEX_FULL = 1;

const KB = 1000;

let state, activity;
let list;
let device;

function port_of() {
	for (let entry in state.ports)
		if (entry.device == device)
			return entry;

	return null;
}

function bytes_of(value) {
	if (value == null)
		return null;

	let units = [ 'KB', 'MB', 'GB', 'TB' ];
	let scaled = value * 1.0 / KB;
	let unit = 0;

	while (scaled >= KB && unit + 1 < length(units)) {
		scaled /= KB;
		unit++;
	}

	if (scaled < 0.1)
		scaled = 0.1;

	if (scaled >= 100)
		return sprintf('%d %s', int(scaled), units[unit]);

	return sprintf('%.1f %s', int(scaled * 10) / 10.0, units[unit]);
}

function speed_of(port) {
	if (!port.up || !port.speed)
		return null;

	let duplex = port.duplex == DUPLEX_FULL ? 'full' : 'half';

	if (port.speed >= 1000)
		return sprintf('%.1f Gb/s %s', port.speed / 1000.0, duplex);

	return sprintf('%d Mb/s %s', port.speed, duplex);
}

function rows_of() {
	let port = port_of();

	if (!port)
		return [];

	let out = [ [ 'Status', port.up ? 'Up' : 'Down',
		      port.up ? C_OK : C_TXT_DIM ] ];
	let speed = speed_of(port);

	if (speed)
		push(out, [ 'Speed', speed ]);

	push(out, [ 'Device', port.device ]);

	let rx = bytes_of(port.rx);
	let tx = bytes_of(port.tx);

	if (rx && tx)
		push(out, [ 'Traffic', sprintf('↓ %s · ↑ %s', rx, tx) ]);

	return out;
}

function key_row(row) {
	return sprintf('%s=%s', row[0], row[1]);
}

function row_of(row) {
	return { label: row[0], value: row[1], value_colour: row[2] };
}

function page_update(source) {
	let rows = rows_of();

	list.set(key_of(rows, key_row), rows, row_of);
}

function page_build(parent, ctx) {
	state = ctx.state;
	activity = ctx.activity;
	device = ctx.params?.device;

	let port = port_of();

	let scroll = list_new(parent, { title: port?.name ?? device ?? 'Port',
					indented: true, height: LIST_H_SUB,
					activity });

	list = rows_new(scroll, { empty: 'Not available', activity });

	page_update(null);
}

return {
	needs: [ 'ports' ],
	build: page_build,
	update: page_update
};
