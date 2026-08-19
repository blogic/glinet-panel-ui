'use strict';

import * as nl from 'nl80211';
import * as uci from 'uci';
import { readfile } from 'fs';
import { state, monotonic, file_read, words, truish,
	 ubus_call } from 'lvgl.sampler';

const IFTYPE_AP = 3;

export const CHART_POINTS = 28;

const MS_WAN	= 1000;
const MS_SLOW	= 5000;

const BUCKETS	= [ 2000, 10000, 50000, 250000,
		    1000000, 5000000, 25000000, 125000000,
		    312500000, 1250000000 ];
const BUCKET_HOLD = 10;

export const DEFAULTS = {
	rx: [],
	tx: [],
	wan_device: null,
	wan_rx: null,
	wan_tx: null,
	wan_ts: null,
	iface: {},
	bands: [],
	wifi: [],
	radios: {},
	bucket: 0,
	bucket_low: 0,
	bss: [],
	networks: [],
	stations: [],
	clients: {},
	ports: []
};

let gnl, ethtool;

try {
	gnl = require('gnl');
}
catch (e) {
	gnl = null;
}

function history_push(list, value) {
	push(list, value);

	while (length(list) > CHART_POINTS)
		shift(list);
}

function bucket_for(peak) {
	for (let bucket in BUCKETS)
		if (peak <= bucket)
			return bucket;

	return BUCKETS[-1];
}

function range_update() {
	let peak = 0;

	for (let value in state.rx)
		if (value > peak)
			peak = value;

	for (let value in state.tx)
		if (value > peak)
			peak = value;

	let want = bucket_for(peak);

	if (want >= state.bucket) {
		state.bucket_low = 0;
		state.bucket = want;

		return;
	}

	if (++state.bucket_low < BUCKET_HOLD)
		return;

	state.bucket_low = 0;
	state.bucket = want;
}

function history_advance(rx, tx) {
	history_push(state.rx, rx);
	history_push(state.tx, tx);
	range_update();
}

function rate_bytes(delta, seconds) {
	if (seconds <= 0)
		return 0;

	return int(delta / seconds);
}

function counter_read(device, name) {
	let raw = file_read(sprintf('/sys/class/net/%s/statistics/%s', device, name));

	return raw != null ? +raw : null;
}

function netdev_counters(device) {
	if (!device)
		return null;

	let rx = counter_read(device, 'rx_bytes');
	let tx = counter_read(device, 'tx_bytes');

	if (rx == null || tx == null)
		return null;

	return { rx, tx };
}

/**
 * wan_device_read - find the netdev the traffic counters are read from
 *
 * Call at start up and on a network.interface event, never from the tick.
 */
export function wan_device_read() {
	let wan = ubus_call('network.interface.wan', 'status');

	state.wan_device = wan?.l3_device ?? wan?.device;
};

function wan_read() {
	let now = monotonic();
	let counters = netdev_counters(state.wan_device);

	if (!counters) {
		state.wan_ts = null;
		history_advance(0, 0);

		return;
	}

	let seconds = state.wan_ts != null ? now - state.wan_ts : 0;
	let d_rx = counters.rx - state.wan_rx;
	let d_tx = counters.tx - state.wan_tx;

	state.wan_rx = counters.rx;
	state.wan_tx = counters.tx;
	state.wan_ts = now;

	if (seconds <= 0 || d_rx < 0 || d_tx < 0) {
		history_advance(0, 0);

		return;
	}

	history_advance(rate_bytes(d_rx, seconds), rate_bytes(d_tx, seconds));
}

function interfaces_read() {
	let dump = ubus_call('network.interface', 'dump');
	let found = {};

	for (let entry in dump?.interface ?? [])
		if (entry?.interface)
			found[entry.interface] = entry;

	state.iface = found;
}

const BAND_5	= 2500;
const BAND_6	= 5900;

function band_of(freq) {
	if (!freq)
		return null;
	if (freq < BAND_5)
		return '2.4 GHz';
	if (freq < BAND_6)
		return '5 GHz';

	return '6 GHz';
}

function security_of(encryption) {
	if (!encryption || encryption == 'none')
		return 'Open';

	if (index(encryption, 'sae') >= 0)
		return 'WPA3';
	if (index(encryption, 'owe') >= 0)
		return 'OWE';
	if (index(encryption, 'psk2') >= 0)
		return 'WPA2';
	if (index(encryption, 'wep') >= 0)
		return 'WEP';
	if (index(encryption, 'psk') >= 0)
		return 'WPA';

	return 'WPA2';
}

function station_count(ifname) {
	let clients = ubus_call(sprintf('hostapd.%s', ifname), 'get_clients')?.clients;

	return clients ? length(clients) : 0;
}

function networks_build() {
	let order = [];
	let by_name = {};

	for (let bss in state.bss) {
		let net = by_name[bss.ssid];

		if (!net) {
			net = {
				ssid: bss.ssid,
				security: bss.security,
				key: bss.key,
				hidden: bss.hidden,
				up: false,
				clients: 0,
				bands: [],
				sections: [],
				ifnames: []
			};

			by_name[bss.ssid] = net;
			push(order, net);
		}

		net.clients += bss.clients;

		if (bss.up)
			net.up = true;

		if (bss.band && index(net.bands, bss.band) < 0)
			push(net.bands, bss.band);

		if (bss.section)
			push(net.sections, bss.section);

		if (bss.ifname)
			push(net.ifnames, bss.ifname);
	}

	state.networks = order;
}

function running_read() {
	let running = {};

	for (let radio, status in state.radios)
		for (let iface in status?.interfaces ?? [])
			if (iface.section)
				running[iface.section] = { ifname: iface.ifname,
							   radio,
							   up: !!status.up };

	return running;
}

function bss_read() {
	let live = {};

	for (let entry in state.wifi)
		live[entry.ifname] = entry;

	let running = running_read();
	let found = [];
	let cursor = uci.cursor();

	cursor.foreach('wireless', 'wifi-iface', function(section) {
		if (!section.ssid)
			return;
		if (section.mode && section.mode != 'ap')
			return;

		let now = running[section['.name']] ?? {};
		let ifname = now.ifname;
		let up = !!(!truish(section.disabled) && now.up && ifname);

		push(found, {
			ssid: section.ssid,
			ifname,
			radio: now.radio ?? section.device,
			section: section['.name'],
			band: band_of(live[ifname]?.wiphy_freq),
			security: security_of(section.encryption),
			key: section.key,
			hidden: truish(section.hidden) ||
				truish(section.ignore_broadcast_ssid),
			up,
			clients: up ? station_count(ifname) : 0
		});
	});

	state.bss = found;

	networks_build();
}

let bands_tried;

function bands_read() {
	let out = [];
	let phys = nl.request(nl.const.NL80211_CMD_GET_WIPHY,
			      nl.const.NLM_F_DUMP, {});

	for (let phy in phys ?? []) {
		let full = nl.request(nl.const.NL80211_CMD_GET_WIPHY, 0,
				      { wiphy: phy.wiphy, split_wiphy_dump: true });

		for (let band in full?.wiphy_bands ?? [])
			if (band?.freqs?.[0]?.freq)
				push(out, band.freqs[0].freq);
	}

	state.bands = out;
}

function wireless_read() {
	/* Once per process: a board with no radio would otherwise enumerate every
	   wiphy every five seconds for ever. */
	if (!bands_tried) {
		bands_tried = true;
		bands_read();
	}

	let ifs = nl.request(nl.const.NL80211_CMD_GET_INTERFACE,
			     nl.const.NLM_F_DUMP, {});
	let found = [];

	for (let entry in ifs ?? [])
		if (entry?.iftype == IFTYPE_AP && entry.ifname)
			push(found, entry);

	state.wifi = found;
	state.radios = ubus_call('network.wireless', 'status') ?? {};

	bss_read();
}

function stations_read() {
	let found = [];

	for (let bss in state.bss) {
		if (!bss.up)
			continue;

		let list = nl.request(nl.const.NL80211_CMD_GET_STATION,
				      nl.const.NLM_F_DUMP, { dev: bss.ifname });

		for (let entry in list ?? []) {
			if (!entry?.mac)
				continue;

			push(found, {
				mac: lc(entry.mac),
				ssid: bss.ssid,
				band: bss.band,
				signal: entry.sta_info?.signal,
				uptime: entry.sta_info?.connected_time
			});
		}
	}

	state.stations = found;
}

const DHCP_HOSTNAME = 12;
const DHCP_VENDOR = 60;

const VENDOR_TYPES = [
	[ 'android', 'phone' ],
	[ 'dhcpcd', 'device' ],
	[ 'MSFT', 'computer' ],
	[ 'udhcp', 'device' ],
	[ 'Linux', 'computer' ],
	[ 'Roku', 'tv' ],
	[ 'PlayStation', 'console' ],
	[ 'Nintendo', 'console' ],
	[ 'HP ', 'printer' ],
	[ 'Brother', 'printer' ],
	[ 'EPSON', 'printer' ]
];

function hex_text(value) {
	if (!value)
		return null;

	let raw = hexdec(value);

	return raw ? trim(raw, '\x00') : null;
}

function client_type(entry) {
	let vendor = entry.vendor;

	if (vendor)
		for (let rule in VENDOR_TYPES)
			if (index(vendor, rule[0]) >= 0)
				return rule[1];

	return 'device';
}

function leases_read(found) {
	let text = readfile('/tmp/dhcp.leases');

	for (let line in split(text ?? '', '\n')) {
		let field = words(line);

		if (length(field) < 4)
			continue;

		let mac = lc(field[1]);
		let record = found[mac] ?? {};

		record.ip ??= field[2];

		if (field[3] != '*')
			record.hostname = field[3];

		found[mac] = record;
	}
}

function snoop_entry(record, entry) {
	if (type(entry) == 'string') {
		record.ip = entry;

		return;
	}

	if (type(entry) != 'object')
		return;

	record.ip = entry.ip;

	let options = entry.options ?? [];

	for (let option in options) {
		if (option.tag == DHCP_HOSTNAME)
			record.hostname = hex_text(option.value);
		else if (option.tag == DHCP_VENDOR)
			record.vendor = hex_text(option.value);
	}
}

function clients_read() {
	let dump = ubus_call('dhcpsnoop', 'dump') ?? {};
	let found = {};

	for (let mac, entry in dump) {
		let record = {};

		snoop_entry(record, entry);
		found[lc(mac)] = record;
	}

	leases_read(found);

	for (let mac, record in found)
		record.type = client_type(record);

	state.clients = found;
}

let ports_cached;

function ports_list() {
	if (ports_cached)
		return ports_cached;

	let board = readfile('/etc/board.json');

	if (!board)
		return [];

	let parsed;

	try {
		parsed = json(board);
	}
	catch (e) {
		return [];
	}

	let network = parsed?.network;
	let out = [];

	if (network?.wan?.device)
		push(out, { name: 'WAN', device: network.wan.device });

	let lan = network?.lan?.ports;

	if (type(lan) != 'array')
		lan = network?.lan?.device ? [ network.lan.device ] : [];

	for (let i = 0; i < length(lan); i++)
		push(out, { name: length(lan) > 1 ? sprintf('LAN %d', i + 1)
						  : 'LAN',
			    device: lan[i] });

	ports_cached = out;

	return out;
}

const DUPLEX_HALF = 0;
const DUPLEX_FULL = 1;

function port_link_gnl(device) {
	if (!ethtool)
		return null;

	try {
		let header = { header: { 'dev-name': device } };
		let up = ethtool.request('linkstate-get', 0, header)?.link;
		let modes = ethtool.request('linkmodes-get', 0, header);

		return { up: !!up, speed: modes?.speed, duplex: modes?.duplex };
	}
	catch (e) {
		return null;
	}
}

function port_link_sysfs(device) {
	let carrier = file_read(sprintf('/sys/class/net/%s/carrier', device));

	if (carrier == null)
		return null;

	let up = carrier == '1';
	let speed = up ? file_read(sprintf('/sys/class/net/%s/speed', device))
		       : null;
	let duplex = up ? file_read(sprintf('/sys/class/net/%s/duplex', device))
			: null;

	return {
		up,
		speed: speed != null ? +speed : null,
		duplex: duplex == 'full' ? DUPLEX_FULL
					 : (duplex == 'half' ? DUPLEX_HALF : null)
	};
}

function port_link(device) {
	return port_link_gnl(device) ?? port_link_sysfs(device);
}

function ports_read() {
	if (gnl && !ethtool) {
		try {
			ethtool = gnl.connect('ethtool');
		}
		catch (e) {
			ethtool = null;
		}
	}

	let found = [];

	for (let port in ports_list()) {
		let link = port_link(port.device);
		let counters = netdev_counters(port.device);

		push(found, { name: port.name, device: port.device,
			      up: link?.up ?? false, speed: link?.speed,
			      duplex: link?.duplex,
			      rx: counters?.rx, tx: counters?.tx });
	}

	state.ports = found;
}

export const SOURCES = [
	{ name: 'wan',        ms: MS_WAN,  retain: true, read: wan_read },
	{ name: 'interfaces', ms: MS_SLOW, read: interfaces_read },
	{ name: 'wireless',   ms: MS_SLOW, read: wireless_read },
	{ name: 'stations',   ms: MS_SLOW, read: stations_read },
	{ name: 'clients',    ms: MS_SLOW, read: clients_read },
	{ name: 'ports',      ms: MS_SLOW, read: ports_read }
];
