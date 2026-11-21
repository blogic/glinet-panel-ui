/*
 * SPDX-License-Identifier: GPL-2.0-only
 */

'use strict';

/*
 * The network filter the Wi-Fi pages share for public mode. Needs no display:
 *
 *	ucode -L /usr/share/ucode/glinet-panel-ui /tmp/visibility.uc
 */

import { networks_visible } from 'lib.wireless';

let failures = 0;
let checks = 0;

function check(what, got, want) {
	let ok = (sprintf('%J', got) == sprintf('%J', want));

	checks++;

	if (!ok)
		failures++;

	printf('%-44s %-30J %s\n', what, got,
	       ok ? 'ok' : sprintf('want %J', want));
}

function ssids(list) {
	return map(list, (net) => net.ssid);
}

const NETS = [
	{ ssid: 'home', key: 'a', up: true },
	{ ssid: 'guest', key: 'b', up: true },
	{ ssid: 'home-bh', key: 'c', up: true, hidden: true }
];

let public_only = (kind, id) => kind == 'ssid' && id == 'guest';
let everything = (kind, id) => true;

check('public mode keeps only listed networks',
      ssids(networks_visible(NETS, public_only)), [ 'guest' ]);
check('private mode keeps every network',
      ssids(networks_visible(NETS, everything)),
      [ 'home', 'guest', 'home-bh' ]);
check('no filter keeps every network',
      ssids(networks_visible(NETS, null)),
      [ 'home', 'guest', 'home-bh' ]);
check('no networks stays empty', networks_visible(null, public_only), []);

printf('\n%s: %d of %d checks failed\n', failures ? 'FAIL' : 'PASS', failures,
       checks);

exit(failures ? 1 : 0);
