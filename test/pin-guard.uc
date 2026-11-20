/*
 * SPDX-License-Identifier: GPL-2.0-only
 */

'use strict';

/*
 * The limit on wrong PINs, as pure arithmetic over an injected clock. Needs
 * no display:
 *
 *	ucode -L /usr/share/ucode/glinet-panel-ui /tmp/pin-guard.uc
 */

import { guard_new, guard_fail, guard_ok, guard_wait, guard_text,
	 GUARD_FREE, GUARD_FIRST, GUARD_MAX, GUARD_FORGET } from 'lib.pin_guard';

let failures = 0;
let checks = 0;

function check(what, got, want) {
	let ok = (sprintf('%J', got) == sprintf('%J', want));

	checks++;

	if (!ok)
		failures++;

	printf('%-44s %-12J %s\n', what, got,
	       ok ? 'ok' : sprintf('want %J', want));
}

let now = 1000;
let g = guard_new();

check('fresh: no wait', guard_wait(g, now), 0);

for (let i = 1; i < GUARD_FREE; i++) {
	guard_fail(g, now);
	check(sprintf('failure %d: no wait', i), guard_wait(g, now), 0);
}

guard_fail(g, now);
check('the last free failure locks', guard_wait(g, now), GUARD_FIRST);
check('the wait counts down', guard_wait(g, now + 10), GUARD_FIRST - 10);
check('over at its end', guard_wait(g, now + GUARD_FIRST), 0);
check('stays over', guard_wait(g, now + GUARD_FIRST + 5), 0);

/* Each failure after a lock doubles it, up to the maximum. */
let wait = GUARD_FIRST;

for (let i = 0; i < 12; i++) {
	now += wait;
	guard_fail(g, now);
	wait = wait * 2 > GUARD_MAX ? GUARD_MAX : wait * 2;
	check(sprintf('next failure %d', i), guard_wait(g, now), wait);
}

check('never above the maximum', guard_wait(g, now), GUARD_MAX);

/* The right PIN ends it. */
guard_ok(g);
check('right PIN: no wait', guard_wait(g, now), 0);
guard_fail(g, now);
check('right PIN: free failures again', guard_wait(g, now), 0);

/* A quiet hour forgets old failures, so a typo weeks later costs nothing. */
g = guard_new();
now = 5000;

for (let i = 1; i < GUARD_FREE; i++)
	guard_fail(g, now);

now += GUARD_FORGET - 1;
guard_fail(g, now);
check('just under the quiet time: still counts', guard_wait(g, now), GUARD_FIRST);

g = guard_new();
now = 5000;

for (let i = 1; i < GUARD_FREE; i++)
	guard_fail(g, now);

now += GUARD_FORGET;
guard_fail(g, now);
check('after the quiet time: forgotten', guard_wait(g, now), 0);

check('text in seconds', guard_text(30), 'Try again in 30 s');
check('text at 59', guard_text(59), 'Try again in 59 s');
check('text at 60', guard_text(60), 'Try again in 1 min');
check('text rounds up', guard_text(61), 'Try again in 2 min');
check('text at the maximum', guard_text(GUARD_MAX), 'Try again in 15 min');

printf('\n%s: %d of %d checks failed\n', failures ? 'FAIL' : 'PASS', failures,
       checks);

exit(failures ? 1 : 0);
