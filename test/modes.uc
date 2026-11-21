/*
 * SPDX-License-Identifier: GPL-2.0-only
 */

'use strict';

/*
 * Mode changes with the real pages: loads the configured roots the way
 * panel.uc does, seeds the sources, then goes public, private and back
 * several times and shows every root in each mode. A page that keeps stale
 * widgets across a rebuild raises here. Takes DRM master:
 *
 *	/etc/init.d/glinet-panel-ui stop
 *	ucode -L /usr/share/ucode/glinet-panel-ui /tmp/modes.uc
 *	/etc/init.d/glinet-panel-ui start
 *
 * PANEL_APP_DIR names another install of the pages.
 */

import * as lv from 'lv';
import { sampler_init } from 'lvgl.sampler';
import { sources_new, DEFAULTS as SYSTEM_DEFAULTS } from 'lvgl.sources';
import { ui_build, ui_seed, nav_flush, view_status, view_wake, view_pin,
	 view_goto, view_logout, view_lock } from 'lvgl.page';
import { loader_init, pages_load, page_load } from 'lvgl.loader';
import { runtime_init, settings } from 'lvgl.runtime';
import { SOURCES, DEFAULTS, CHART_POINTS } from 'lib.sources';

const CONFIG = 'glinet_panel';
const APP_DIR = getenv('PANEL_APP_DIR') ?? '/usr/share/ucode/glinet-panel-ui';
const ROUNDS = 3;

let failures = 0;
let checks = 0;

function survives(what, fn) {
	checks++;

	try {
		fn();
		lv.refresh();
		printf('%-44s ok\n', what);
	} catch (e) {
		failures++;
		printf('%-44s %s\n', what, e);
	}
}

function every_root(mode) {
	for (let name in view_status().pages)
		survives(sprintf('%s: show %s', mode, name), () => view_goto(name));
}

if (!lv.init())
	die('cannot initialise LVGL');

if (!lv.display_drm(getenv('PANEL_DRM_DEVICE') ?? '/dev/dri/card0', -1))
	die('cannot open the DRM display');

runtime_init({ config: CONFIG });
loader_init({ dir: APP_DIR, config: CONFIG });
sampler_init([ ...SOURCES, ...sources_new({ config: CONFIG }) ],
	     { ...SYSTEM_DEFAULTS, ...DEFAULTS });

/* The real keypad is driven by touch; this one hands over its unlock. */
let pin = { name: 'pin', needs: [], unlock: null };

pin.build = function(parent, ctx) {
	pin.unlock = ctx.unlock;
};

ui_build(pages_load(settings.pages, settings.sections), page_load('lock', null),
	 pin, '123456', null, true, true,
	 { points: CHART_POINTS, card_opa: lv.OPA_COVER,
	   public: settings.public });
ui_seed();

survives('wake into public', view_wake);
every_root('public');

for (let i = 1; i <= ROUNDS; i++) {
	survives(sprintf('round %d: PIN', i), function() {
		view_pin();
		pin.unlock();
		nav_flush();
	});
	every_root('private');
	survives(sprintf('round %d: logout', i), view_logout);
	every_root('public');
	survives(sprintf('round %d: PIN, then timeout', i), function() {
		view_pin();
		pin.unlock();
		nav_flush();
		view_lock();
		view_wake();
	});
}

printf('\n%s: %d of %d checks failed\n', failures ? 'FAIL' : 'PASS', failures,
       checks);

lv.drm_drop_master();

exit(failures ? 1 : 0);
