/*
 * SPDX-License-Identifier: GPL-2.0-only
 */

'use strict';

/*
 * Every background comes in both orientations, at the panel's size, so a
 * turned panel is covered edge to edge. Reads only the PNG headers; needs no
 * display:
 *
 *	ucode /tmp/backgrounds.uc [asset dir]
 */

import { readfile } from 'fs';

const DIR = ARGV[0] ?? '/usr/share/glinet-panel-ui';
const NAMES = [
	'bg-1-vert-lines', 'bg-2-horiz-lines', 'bg-3-vert-waves',
	'bg-4-horiz-waves', 'bg-5-diag-steep', 'bg-6-diag-shallow',
	'bg-7-diag-waves-steep', 'bg-8-diag-waves-shallow'
];

let failures = 0;
let checks = 0;

function check(what, got, want) {
	let ok = (sprintf('%J', got) == sprintf('%J', want));

	checks++;

	if (!ok)
		failures++;

	printf('%-52s %-12J %s\n', what, got,
	       ok ? 'ok' : sprintf('want %J', want));
}

/* Width and height from the IHDR chunk, which a PNG always starts with. */
function png_size(path) {
	let head = readfile(path, 24);

	if (!head || length(head) < 24)
		return null;

	let be = (o) => (ord(head, o) << 24) | (ord(head, o + 1) << 16) |
			(ord(head, o + 2) << 8) | ord(head, o + 3);

	return [ be(16), be(20) ];
}

for (let name in NAMES) {
	check(name + ' landscape',
	      png_size(sprintf('%s/backgrounds/%s.png', DIR, name)), [ 320, 240 ]);
	check(name + ' portrait',
	      png_size(sprintf('%s/backgrounds-portrait/%s.png', DIR, name)),
	      [ 240, 320 ]);
}

printf('\n%s: %d of %d checks failed\n', failures ? 'FAIL' : 'PASS', failures,
       checks);

exit(failures ? 1 : 0);
