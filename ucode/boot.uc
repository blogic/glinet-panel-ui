'use strict';

import * as lv from 'lv';
import * as uloop from 'uloop';
import { cos } from 'math';
import { IMAGE_LOGO } from './lib/assets.uc';
import { W, H } from './lib/theme.uc';
import { centre } from './lib/layout.uc';

/* White, not the panel's black: the splash stands in for firmware that has not
   started, and the theme belongs to the application. */
const BG = 0xffffff;
const DOT = 0x00ace2;

const DOT_COUNT = 3;
const DOT_SPACING = 20;
const DOT_MIN_R = 2;
const DOT_MAX_R = 5;
const DOT_MIN_OPA = 0.35;

const FRAMES = 12;
const FRAME_MS = 1000 / FRAMES;

const THROB_W = DOT_COUNT * DOT_SPACING;
const THROB_H = 2 * DOT_MAX_R + 4;
const THROB_X = centre(W, THROB_W);
const THROB_Y = H * 4 / 5 - THROB_H / 2;

const PI = 3.14159265358979;

let dots = [];
let frame = 0;
let timers = {};

/* uloop has no disarm for a one shot and both timers re-arm themselves, so the
   callbacks gate on this: a flush after master is gone fails with EACCES. */
let released = false;

function lv_tick() {
	if (released)
		return;

	let delay = lv.timer_handler();

	if (delay < 5)
		delay = 5;
	else if (delay > 200)
		delay = 200;

	timers.lv.set(delay);
}

function throb_step() {
	if (released)
		return;

	for (let i = 0; i < DOT_COUNT; i++) {
		let phase = frame * 1.0 / FRAMES - i * 1.0 / DOT_COUNT;
		let wave = (cos(2 * PI * phase) + 1) / 2;
		let size = int((DOT_MIN_R + (DOT_MAX_R - DOT_MIN_R) * wave) * 2 + 0.5);
		let opa = int(255 * (DOT_MIN_OPA + (1 - DOT_MIN_OPA) * wave));
		let half = int(size / 2);

		dots[i].set({
			x: THROB_X + i * DOT_SPACING + DOT_SPACING / 2 - half,
			y: THROB_Y + THROB_H / 2 - half,
			w: size,
			h: size
		});
		dots[i].style({ radius: size, bg_opa: opa });
	}

	frame = (frame + 1) % FRAMES;

	timers.throb.set(FRAME_MS);
}

function build() {
	let screen = lv.screen();

	screen.style({
		bg_color: BG,
		bg_opa: lv.OPA_COVER,
		border_width: 0,
		pad_all: 0
	});
	screen.scrollbar(lv.SCROLLBAR_OFF);
	screen.scrollable(false);

	let logo = lv.image(screen);

	logo.src(IMAGE_LOGO);
	logo.set({ x: centre(W, logo.width()), y: centre(H, logo.height()) });

	for (let i = 0; i < DOT_COUNT; i++) {
		let dot = lv.obj(screen);

		dot.style({ bg_color: DOT, border_width: 0, pad_all: 0 });
		dot.clickable(false);
		dot.scrollable(false);

		push(dots, dot);
	}
}

if (!lv.init())
	die('cannot initialise LVGL');

if (!lv.display_drm(getenv('PANEL_DRM_DEVICE') ?? '/dev/dri/card0', -1))
	die('cannot open the DRM display');

build();

uloop.init();

timers.lv = uloop.timer(-1, lv_tick);
timers.throb = uloop.timer(-1, throb_step);

throb_step();
lv.refresh();

timers.lv.set(5);

/* Drop master and stay alive. Exiting would destroy a framebuffer that is still
   on the plane, and the kernel answers that by disabling the CRTC. */
uloop.signal('SIGUSR1', function() {
	released = true;

	lv.drm_drop_master();
});

uloop.signal('SIGTERM', function() {
	uloop.end();
});

uloop.run();
