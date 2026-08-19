'use strict';

const SPECIAL = [ '\\', ';', ',', ':', '"' ];

function escaped(value) {
	let out = value ?? '';

	for (let ch in SPECIAL)
		out = replace(out, ch, '\\' + ch);

	return out;
}

function auth_of(security) {
	if (security == 'Open' || security == 'OWE')
		return 'nopass';
	if (security == 'WEP')
		return 'WEP';

	return 'WPA';
}

/**
 * qr_payload - build the WIFI: join string a phone camera reads
 * @net: a network from state.networks, carrying ssid, key, security and hidden
 *
 * Return: the payload string.
 */
export function qr_payload(net) {
	let auth = auth_of(net.security);
	let out = sprintf('WIFI:T:%s;S:%s;', auth, escaped(net.ssid));

	if (auth != 'nopass')
		out += sprintf('P:%s;', escaped(net.key));

	if (net.hidden)
		out += 'H:true;';

	return out + ';';
};
