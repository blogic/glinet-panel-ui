/*
 * SPDX-License-Identifier: GPL-2.0-only
 */

'use strict';

/*
 * Where the idle screen puts its parts, landscape and portrait, with and
 * without the weather, in 24 and 12 hour form. Every part has to stay on the
 * glass and clear of the others, and landscape has to stay where it was.
 * Pure arithmetic, needs no display:
 *
 *	ucode -L /usr/share/ucode/glinet-panel-ui /tmp/idle-layout.uc
 */

import { idle_layout } from 'lib.idle';

let failures = 0;
let checks = 0;

function check(what, got, want) {
	let ok = (sprintf('%J', got) == sprintf('%J', want));

	checks++;

	if (!ok)
		failures++;

	printf('%-52s %-10J %s\n', what, got,
	       ok ? 'ok' : sprintf('want %J', want));
}

/* Measured on the GL-BE14000 for "23:57" and its two halves. */
const FONTS = {
	date_h: 25, clock_h: 85, mer_h: 19, rate_h: 25, small_h: 35,
	cond_h: 19, temp_h: 32
};
const WIDTHS = { clock: 256, clock_line: 121, small: 101 };

function inside(r, w, h) {
	return r.x >= 0 && r.y >= 0 && r.x + r.w <= w && r.y + r.h <= h;
}

function overlap(a, b) {
	return a.x < b.x + b.w && b.x < a.x + a.w &&
	       a.y < b.y + b.h && b.y < a.y + a.h;
}

function sound(name, w, h, h24, weather) {
	let l = idle_layout({ w, h, h24, weather, fonts: FONTS, widths: WIDTHS });
	let parts = l.shown;

	for (let p in parts)
		check(sprintf('%s: %s on the glass', name, p),
		      inside(l[p], w, h), true);

	for (let i = 0; i < length(parts); i++)
		for (let j = i + 1; j < length(parts); j++)
			check(sprintf('%s: %s clear of %s', name, parts[i],
				      parts[j]),
			      overlap(l[parts[i]], l[parts[j]]), false);

	return l;
}

printf('== landscape stays where it was ==\n');

let l = idle_layout({ w: 320, h: 240, h24: true, weather: false,
		      fonts: FONTS, widths: WIDTHS });

check('date y', l.date.y, 19);
check('clock y', l.clock.y, 76);
check('clock x, centred', l.clock.x, 32);
check('rate y', l.rate.y, 195);
check('one line of digits', l.clock_lines, 1);

for (let h24 in [ true, false ])
	for (let weather in [ false, true ]) {
		let name = sprintf('%s %s %s', 'landscape', h24 ? '24h' : '12h',
				   weather ? 'weather' : 'plain');

		printf('\n== %s ==\n', name);
		sound(name, 320, 240, h24, weather);
	}

for (let h24 in [ true, false ])
	for (let weather in [ false, true ]) {
		let name = sprintf('%s %s %s', 'portrait', h24 ? '24h' : '12h',
				   weather ? 'weather' : 'plain');

		printf('\n== %s ==\n', name);
		let p = sound(name, 240, 320, h24, weather);

		if (!weather)
			check(name + ': hours over minutes', p.clock_lines, 2);
	}

printf('\n%s: %d of %d checks failed\n', failures ? 'FAIL' : 'PASS', failures,
       checks);

exit(failures ? 1 : 0);
