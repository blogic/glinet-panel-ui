/*
 * SPDX-License-Identifier: GPL-2.0-only
 */

'use strict';

/*
 * Every page and sub page must load. A sub page is only read when somebody
 * opens it, so a syntax error there shows nowhere else. Needs no display:
 *
 *	ucode -L /usr/share/ucode/glinet-panel-ui /tmp/pages-load.uc
 *
 * PANEL_APP_DIR names another install of the pages.
 */

import { lsdir } from 'fs';

const APP_DIR = getenv('PANEL_APP_DIR') ?? '/usr/share/ucode/glinet-panel-ui';

let failures = 0;
let checks = 0;

/* loadfile and not page_load: that also leaves out a page whose options are
   not set, like the weather page without a position. */
function loads(kind, dir) {
	for (let file in lsdir(sprintf('%s/%s', APP_DIR, dir))) {
		if (substr(file, 0, 1) == '.' || !match(file, /\.uc$/))
			continue;

		let name = substr(file, 0, length(file) - 3);
		let ok = false;

		try {
			ok = (loadfile(sprintf('%s/%s/%s', APP_DIR, dir, file)) != null);
		} catch (e) {
			printf('%s\n', e);
		}

		checks++;

		if (!ok)
			failures++;

		printf('%-10s %-24s %s\n', kind, name, ok ? 'ok' : 'FAILS TO LOAD');
	}
}

loads('page', 'pages');
loads('sub page', 'subpages');

printf('\n%s: %d of %d checks failed\n', failures ? 'FAIL' : 'PASS', failures,
       checks);

exit(failures ? 1 : 0);
