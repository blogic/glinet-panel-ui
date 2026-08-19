'use strict';

import { LIST_H_SUB } from '../lib/theme.uc';
import { list_new } from '../lib/widget.uc';
import { key_of } from '../lib/layout.uc';
import { rows_new } from '../lib/component/rows.uc';

const TYPE_NAMES = {
	computer: 'Computer',
	phone: 'Phone',
	tv: 'TV',
	console: 'Console',
	printer: 'Printer',
	device: 'Device'
};

const HOUR = 3600;
const DAY = 24 * HOUR;

let state, activity;
let list;
let mac;

function station_of() {
	for (let entry in state.stations)
		if (entry.mac == mac)
			return entry;

	return null;
}

function uptime_of(seconds) {
	if (seconds == null)
		return null;

	if (seconds >= DAY)
		return sprintf('%dd %dh', int(seconds / DAY),
			       int((seconds % DAY) / HOUR));

	if (seconds >= HOUR)
		return sprintf('%dh %dm', int(seconds / HOUR),
			       int((seconds % HOUR) / 60));

	return sprintf('%dm', int(seconds / 60));
}

function rows_of() {
	let station = station_of();

	if (!station)
		return [];

	let record = state.clients[mac];
	let out = [];

	if (record?.type)
		push(out, [ 'Type', TYPE_NAMES[record.type] ?? 'Device' ]);

	if (record?.ip)
		push(out, [ 'Address', record.ip ]);

	if (station.ssid)
		push(out, [ 'Network', station.band
			    ? sprintf('%s · %s', station.ssid, station.band)
			    : station.ssid ]);

	if (station.signal != null)
		push(out, [ 'Signal', sprintf('−%d dBm', -station.signal) ]);

	push(out, [ 'MAC', uc(mac) ]);

	let up = uptime_of(station.uptime);

	if (up)
		push(out, [ 'Connected', up ]);

	return out;
}

function key_row(row) {
	return sprintf('%s=%s', row[0], row[1]);
}

function row_of(row) {
	return { label: row[0], value: row[1] };
}

function page_update(source) {
	let rows = rows_of();

	list.set(key_of(rows, key_row), rows, row_of);
}

function page_build(parent, ctx) {
	state = ctx.state;
	activity = ctx.activity;
	mac = ctx.params?.mac;

	let title = state.clients[mac]?.hostname ?? uc(substr(mac ?? '', 9));

	let scroll = list_new(parent, { title, indented: true,
					height: LIST_H_SUB, activity });

	list = rows_new(scroll, { empty: 'Not connected', activity });

	page_update(null);
}

return {
	needs: [ 'wireless', 'stations', 'clients' ],
	build: page_build,
	update: page_update
};
