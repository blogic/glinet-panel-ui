'use strict';

import * as ubus from 'ubus';
import * as uci from 'uci';

/**
 * ssid_enable - turn every wifi-iface of a network on or off
 * @net: a network from state.networks, carrying its uci sections
 * @on: true to enable, false to disable
 *
 * Return: true once the reload is queued, false if the network has no section.
 */
export function ssid_enable(net, on) {
	if (!length(net?.sections ?? []))
		return false;

	let cursor = uci.cursor();

	if (!cursor.load('wireless'))
		return false;

	for (let section in net.sections)
		cursor.set('wireless', section, 'disabled', on ? '0' : '1');

	cursor.commit('wireless');

	/* Deferred: a blocking call here would stop the tick until netifd is done. */
	try {
		ubus.defer({
			object: 'network',
			method: 'reload',
			data: {},
			cb: function(status) {
				if (status != ubus.STATUS_OK)
					warn(sprintf('panel: wireless reload failed: %d\n',
						     status));
			}
		});
	}
	catch (e) {
		warn(sprintf('panel: wireless reload failed: %s\n', e));
	}

	return true;
};
