'use strict';

import { ROW_H_ROOT } from '../lib/theme.uc';
import { IMAGE_COMPUTER, IMAGE_CONSOLE, IMAGE_DEVICE, IMAGE_PHONE,
	 IMAGE_PRINTER, IMAGE_TV } from '../lib/assets.uc';
import { list_new, signal_level } from '../lib/widget.uc';
import { key_of } from '../lib/layout.uc';
import { rows_new } from '../lib/component/rows.uc';

const TYPE_ICONS = {
	computer: IMAGE_COMPUTER,
	phone: IMAGE_PHONE,
	tv: IMAGE_TV,
	console: IMAGE_CONSOLE,
	printer: IMAGE_PRINTER,
	device: IMAGE_DEVICE
};

let state, activity, open;
let list;

function label_of(station) {
	let record = state.clients[station.mac];

	if (record?.hostname)
		return record.hostname;

	return uc(substr(station.mac, 9));
}

function icon_of(station) {
	let type = state.clients[station.mac]?.type;

	return TYPE_ICONS[type] ?? IMAGE_DEVICE;
}

/* No signal: it crosses a threshold at tick rate, and rebuilding for it would
   throw the scroll position back to the top. Set on the bars in place. */
function key_station(station) {
	return sprintf('%s|%s', station.mac, label_of(station));
}

function tap_handler(mac) {
	return function() {
		activity();
		open('client', { mac });
	};
}

function row_of(station) {
	return {
		icon: icon_of(station),
		label: label_of(station),
		signal: signal_level(station.signal),
		accessory: 'chevron',
		on_tap: tap_handler(station.mac)
	};
}

function page_update(source) {
	let stations = state.stations;

	if (list.set(key_of(stations, key_station), stations, row_of))
		return;

	for (let i = 0; i < length(list.rows); i++)
		list.rows[i].signal.set(signal_level(stations[i].signal));
}

function page_build(parent, ctx) {
	state = ctx.state;
	activity = ctx.activity;
	open = ctx.open;

	let scroll = list_new(parent, { title: 'Clients', activity });

	list = rows_new(scroll, { empty: 'No clients', h: ROW_H_ROOT,
				  large: true, activity });
}

return {
	requires: 'dhcpsnoop',
	needs: [ 'wireless', 'stations', 'clients' ],
	build: page_build,
	enter: page_update,
	update: page_update
};
