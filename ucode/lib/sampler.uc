'use strict';

import * as nl from 'nl80211';
import * as ubus from 'ubus';
import * as uci from 'uci';
import * as uloop from 'uloop';
import { readfile } from 'fs';

const IFTYPE_AP = 3;

export const CHART_POINTS = 28;

const MS_WAN	= 1000;
const MS_LOAD	= 2000;
const MS_SLOW	= 5000;
const MS_CLOCK	= 1000;

const BUCKETS	= [ 2000, 10000, 50000, 250000,
		    1000000, 5000000, 25000000, 125000000,
		    312500000, 1250000000 ];
const BUCKET_HOLD = 10;

const STAT_IDLE	= 4;
const STAT_IOWAIT = 5;

export const state = {
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
	cpu: 0,
	mem: 0,
	flash: 0,
	temp: null,
	cpu_busy: null,
	cpu_total: null,
	clock_12: '',
	clock_24: '',
	meridiem: '',
	date: '',
	bucket: 0,
	bucket_low: 0,
	bss: [],
	networks: [],
	stations: [],
	clients: {},
	ports: [],
	weather: null
};

let gnl, ethtool;

try {
	gnl = require('gnl');
}
catch (e) {
	gnl = null;
}

let sources = {};
let watchers = [];
let awake;

/**
 * monotonic - seconds from a clock that does not step
 *
 * Return: a float. For measuring an interval, never for a wall time.
 */
export function monotonic() {
	let now = clock(true);

	return now[0] + now[1] / 1000000000.0;
};

function file_read(path) {
	let data = readfile(path);

	return data ? trim(data) : null;
}

function words(line) {
	return filter(split(replace(trim(line), /[ \t]+/g, ' '), ' '),
		      part => part != '');
}

const UCI_TRUE = [ '1', 'on', 'true', 'yes', 'enabled' ];

function truish(value) {
	return index(UCI_TRUE, lc(value ?? '')) >= 0;
}

function ubus_call(object, method, data) {
	try {
		return ubus.call({ object, method, data: data ?? {} });
	}
	catch (e) {
		return null;
	}
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

function cpu_read() {
	let stat = file_read('/proc/stat');

	if (!stat)
		return;

	let field = words(split(stat, '\n')[0]);
	let total = 0;

	for (let i = 1; i < length(field); i++)
		total += +field[i];

	let idle = +field[STAT_IDLE] +
		   (length(field) > STAT_IOWAIT ? +field[STAT_IOWAIT] : 0);
	let busy = total - idle;

	if (state.cpu_total != null && total > state.cpu_total)
		state.cpu = int((busy - state.cpu_busy) * 100.0 /
				(total - state.cpu_total));

	state.cpu_busy = busy;
	state.cpu_total = total;
}

function sysinfo_read() {
	let info = ubus_call('system', 'info');

	if (!info)
		return;

	let mem = info.memory;

	if (mem?.total > 0)
		state.mem = int((mem.total - mem.available) * 100 / mem.total);

	let root = info.root;

	if (root?.total > 0)
		state.flash = int(root.used * 100 / root.total);
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

function temp_read() {
	let milli = file_read('/sys/class/thermal/thermal_zone0/temp');

	if (milli != null)
		state.temp = int(+milli / 1000);
}

/* ucode counts wday from one and starts it at Monday, not at Sunday. */
const WEEKDAYS = [ 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
		   'Saturday', 'Sunday' ];
const MONTHS = [ 'January', 'February', 'March', 'April', 'May', 'June',
		 'July', 'August', 'September', 'October', 'November',
		 'December' ];

function clock_read() {
	let now = localtime(time());
	let hour = now.hour % 12;

	state.clock_12 = sprintf('%d:%02d', hour == 0 ? 12 : hour, now.min);
	state.clock_24 = sprintf('%02d:%02d', now.hour, now.min);
	state.meridiem = now.hour < 12 ? 'AM' : 'PM';
	state.date = sprintf('%s, %d %s', WEEKDAYS[now.wday - 1], now.mday,
			     MONTHS[now.mon - 1]);
}

function source_notify(name, broadcast) {
	for (let fn in watchers)
		fn(name, broadcast);
}

const WX_HOST	= 'https://api.open-meteo.com/v1/forecast';
const WX_CURRENT = 'temperature_2m,apparent_temperature,weather_code,is_day';
const WX_DAILY	= 'weather_code,temperature_2m_max,temperature_2m_min';
const WX_DAYS	= 5;

const WX_FETCH	= '/usr/bin/wget';
const WX_TMP	= '/tmp/glinet-panel-weather.json';
const WX_TIMEOUT = 15;

const WX_TTL	= 3600;
const MS_WX	= 300000;

const WX_LAT_MAX = 90;
const WX_LON_MAX = 180;

let wx_busy, wx_ts;

function wx_config() {
	let cursor = uci.cursor();

	if (!cursor.load('glinet_panel'))
		return null;

	let lat = cursor.get('glinet_panel', '@panel[0]', 'latitude');
	let lon = cursor.get('glinet_panel', '@panel[0]', 'longitude');

	/* Absent is refused here and not by the range test: +null is 0 and 0 is a
	   latitude, which would put an unset panel in the Gulf of Guinea. */
	if (lat == null || lat == '' || lon == null || lon == '')
		return null;

	lat = +lat;
	lon = +lon;

	if (!(lat >= -WX_LAT_MAX && lat <= WX_LAT_MAX))
		return null;
	if (!(lon >= -WX_LON_MAX && lon <= WX_LON_MAX))
		return null;

	return { lat, lon };
}

const WX_CODES = [
	[ [ 0 ],			'clear',  'Clear' ],
	[ [ 1 ],			'partly', 'Mainly clear' ],
	[ [ 2 ],			'partly', 'Partly cloudy' ],
	[ [ 3 ],			'cloud',  'Overcast' ],
	[ [ 45, 48 ],			'cloud',  'Fog' ],
	[ [ 51, 53, 55, 56, 57 ],	'rain',   'Drizzle' ],
	[ [ 61, 63, 65, 66, 67 ],	'rain',   'Rain' ],
	[ [ 80, 81, 82 ],		'rain',   'Showers' ],
	[ [ 71, 73, 75, 77 ],		'snow',   'Snow' ],
	[ [ 85, 86 ],			'snow',   'Snow showers' ],
	[ [ 95, 96, 99 ],		'storm',  'Thunderstorm' ]
];

function wx_code(code) {
	for (let row in WX_CODES)
		if (index(row[0], code) >= 0)
			return { glyph: row[1], text: row[2] };

	return { glyph: 'cloud', text: '—' };
}

function wx_round(value) {
	if (type(value) != 'double' && type(value) != 'int')
		return null;

	return int(value + (value < 0 ? -0.5 : 0.5));
}

function wx_days(daily) {
	let out = [];
	let today = localtime(time()).wday - 1;

	for (let i = 0; i < WX_DAYS; i++) {
		let code = daily.weather_code?.[i];

		if (code == null)
			break;

		push(out, {
			name: substr(WEEKDAYS[(today + i) % 7], 0, 3),
			glyph: wx_code(code).glyph,
			hi: wx_round(daily.temperature_2m_max?.[i]),
			lo: wx_round(daily.temperature_2m_min?.[i])
		});
	}

	return out;
}

function wx_parse(raw) {
	let doc;

	try {
		doc = json(raw);
	}
	catch (e) {
		return false;
	}

	if (!doc || doc.error || !doc.current || !doc.daily)
		return false;

	let now = doc.current;
	let sky = wx_code(now.weather_code);

	state.weather = {
		temp: wx_round(now.temperature_2m),
		feels: wx_round(now.apparent_temperature),
		glyph: sky.glyph,
		text: sky.text,
		day: now.is_day != 0,
		days: wx_days(doc.daily)
	};

	return true;
}

function weather_read() {
	if (wx_busy)
		return;
	if (state.weather && wx_ts != null && monotonic() - wx_ts < WX_TTL)
		return;

	let cfg = wx_config();

	if (!cfg)
		return;

	let url = sprintf('%s?latitude=%.4f&longitude=%.4f&current=%s&daily=%s' +
			  '&timezone=auto&forecast_days=%d',
			  WX_HOST, cfg.lat, cfg.lon, WX_CURRENT, WX_DAILY, WX_DAYS);

	wx_busy = true;

	let proc = uloop.process(WX_FETCH,
				 [ '-q', '-O', WX_TMP,
				   '-T', sprintf('%d', WX_TIMEOUT), url ],
				 null, function(code) {
		wx_busy = false;

		if (code != 0)
			return;

		if (wx_parse(readfile(WX_TMP))) {
			wx_ts = monotonic();
			source_notify('weather', true);
		}
	});

	if (!proc)
		wx_busy = false;
}

const SOURCES = [
	{ name: 'wan',    ms: MS_WAN,    retain: true, read: wan_read },
	{ name: 'clock',  ms: MS_CLOCK,  read: clock_read },
	{ name: 'cpu',     ms: MS_LOAD, read: cpu_read },
	{ name: 'sysinfo', ms: MS_LOAD, read: sysinfo_read },
	{ name: 'temp',    ms: MS_SLOW, read: temp_read },
	{ name: 'interfaces', ms: MS_SLOW, read: interfaces_read },
	{ name: 'wireless',   ms: MS_SLOW, read: wireless_read },
	{ name: 'stations',   ms: MS_SLOW, read: stations_read },
	{ name: 'clients',    ms: MS_SLOW, read: clients_read },
	{ name: 'ports',      ms: MS_SLOW, read: ports_read },
	{ name: 'weather',    ms: MS_WX,   retain: true, broadcast: true,
	  read: weather_read }
];

function source_fire(src) {
	src.read();

	source_notify(src.name, src.broadcast);
}

function source_timer_new(src) {
	return uloop.interval(0, () => source_fire(src));
}

function source_wanted(src) {
	return src.retain || (awake && src.users > 0);
}

function source_sync(src) {
	let want = source_wanted(src);

	if (want == src.armed)
		return;

	src.armed = want;

	if (want)
		src.read();

	/* Zero is the disarm: cancel() would free the callback binding. */
	src.timer.set(want ? src.ms : 0);
}

/**
 * sampler_init - build the source table and its timers
 *
 * Every source starts disarmed. Call once, before any page is built.
 */
export function sampler_init() {
	for (let decl in SOURCES) {
		let src = { ...decl, users: 0, armed: false };

		src.timer = source_timer_new(src);
		sources[src.name] = src;
	}
};

/**
 * source_watch - register a handler for a sample
 * @fn: called with the source name and its broadcast flag
 */
export function source_watch(fn) {
	push(watchers, fn);
};

/**
 * source_seed - read a source once without arming it
 * @names: source names, in the order they should be read
 *
 * Fills state so a page can be drawn before it has ever been shown. An already
 * armed source is skipped, and no watcher is called.
 */
export function source_seed(names) {
	for (let name in names) {
		let src = sources[name];

		if (!src || src.armed)
			continue;

		src.read();
	}
};

/**
 * source_subscribe - claim sources for a page that is being entered
 * @names: the page's needs, in the order they should be armed
 *
 * A source arms on its first user and is read once immediately, so a page whose
 * source depends on another lists that one first.
 */
export function source_subscribe(names) {
	for (let name in names) {
		let src = sources[name];

		if (!src)
			continue;

		src.users++;
		source_sync(src);
	}
};

/**
 * source_release - drop a page's claim on its sources
 * @names: the page's needs
 *
 * A source with no users left and no retain flag stops sampling.
 */
export function source_release(names) {
	for (let name in names) {
		let src = sources[name];

		if (!src || --src.users > 0)
			continue;

		source_sync(src);
	}
};

/**
 * sampler_awake - whether the subscribed sources should sample
 * @flag: false once the panel is idle
 *
 * A retained source keeps running either way.
 */
export function sampler_awake(flag) {
	awake = flag;

	for (let name, src in sources)
		source_sync(src);
};
