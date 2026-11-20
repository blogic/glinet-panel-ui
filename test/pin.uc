/*
 * SPDX-License-Identifier: GPL-2.0-only
 */

'use strict';

/*
 * The real keypad page against the limit on wrong PINs, on an injected clock.
 * Takes DRM master:
 *
 *	/etc/init.d/glinet-panel-ui stop
 *	ucode -L /usr/share/ucode/glinet-panel-ui /tmp/pin.uc
 *	/etc/init.d/glinet-panel-ui start
 *
 * PANEL_APP_DIR names another install of the pages.
 */

import * as lv from 'lv';
import * as uloop from 'uloop';
import { loader_init, page_load } from 'lvgl.loader';
import { runtime_init } from 'lvgl.runtime';
import { GUARD_FREE, GUARD_FIRST } from 'lib.pin_guard';

const RIGHT = '123456';
const WRONG = '000000';
const SHAKE_DONE_MS = 400;

let failures = 0;
let checks = 0;

function check(what, got, want) {
	let ok = (sprintf('%J', got) == sprintf('%J', want));

	checks++;

	if (!ok)
		failures++;

	printf('%-44s %-22J %s\n', what, got,
	       ok ? 'ok' : sprintf('want %J', want));
}

if (!lv.init())
	die('cannot initialise LVGL');

if (!lv.display_drm(getenv('PANEL_DRM_DEVICE') ?? '/dev/dri/card0', -1))
	die('cannot open the DRM display');

uloop.init();

runtime_init({ config: 'glinet_panel' });
loader_init({ dir: getenv('PANEL_APP_DIR') ??
		   '/usr/share/ucode/glinet-panel-ui',
	      config: 'glinet_panel' });

let now = 1000;
let unlocks = 0;
let page = page_load('pin', null);
let screen = lv.screen_create();

lv.screen_load(screen);

page.build(screen, {
	pin: RIGHT,
	unlock: function() { unlocks++; },
	activity: function() {},
	card_opa: lv.OPA_COVER,
	now: function() { return now; }
});
page.enter();

/* Lets the shake of a refused PIN finish. */
function settle() {
	uloop.timer(SHAKE_DONE_MS, function() { uloop.end(); });
	uloop.run();
}

function type_pin(pin) {
	for (let i = 0; i < length(pin); i++)
		page.digit(substr(pin, i, 1));
}

function prompt() {
	return page.status().prompt;
}

check('starts open', prompt(), 'Enter PIN');

for (let i = 1; i < GUARD_FREE; i++) {
	type_pin(WRONG);
	settle();
	check(sprintf('wrong PIN %d', i), prompt(), 'Incorrect PIN');
	check(sprintf('wrong PIN %d: dots cleared', i), page.status().entered, 0);
}

type_pin(WRONG);
settle();
check('last free PIN locks', prompt(),
      sprintf('Try again in %d s', GUARD_FIRST));

type_pin(RIGHT);
check('locked: the right PIN does nothing', unlocks, 0);
check('locked: no dots', page.status().entered, 0);
check('locked: the prompt stays', prompt(),
      sprintf('Try again in %d s', GUARD_FIRST));

now += 10;
page.refresh();
check('the prompt counts down', prompt(),
      sprintf('Try again in %d s', GUARD_FIRST - 10));

/* Leaving the keypad must not lift it. */
page.leave();
page.enter();
check('back on the keypad: still locked', prompt(),
      sprintf('Try again in %d s', GUARD_FIRST - 10));
type_pin(RIGHT);
check('back on the keypad: PIN does nothing', unlocks, 0);

now += GUARD_FIRST - 10;
page.refresh();
check('over: the prompt returns', prompt(), 'Enter PIN');

type_pin(WRONG);
settle();
check('next failure doubles', prompt(),
      sprintf('Try again in %d min', GUARD_FIRST * 2 / 60));

now += GUARD_FIRST * 2;
page.refresh();
type_pin(RIGHT);
check('over: the right PIN unlocks', unlocks, 1);

page.enter();
type_pin(WRONG);
settle();
check('after unlock: free failures again', prompt(), 'Incorrect PIN');

page.leave();
lv.refresh();

printf('\n%s: %d of %d checks failed\n', failures ? 'FAIL' : 'PASS', failures,
       checks);

lv.drm_drop_master();

exit(failures ? 1 : 0);
