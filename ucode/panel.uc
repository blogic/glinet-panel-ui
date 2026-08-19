'use strict';

import * as lv from 'lv';
import * as ubus from 'ubus';
import * as uloop from 'uloop';
import { readfile, unlink } from 'fs';
import { state, sampler_init, sampler_awake,
	 wan_device_read } from './lib/sampler.uc';
import { ui_build, ui_seed, view_status, view_goto, view_open,
	 view_back } from './lib/page.uc';
import { page_load, pages_load } from './lib/loader.uc';
import { runtime_init, runtime_start, runtime_wake,
	 settings } from './lib/runtime.uc';

const SHOT_DIR = '/tmp';

const TEST_PAGES = [ 'touch', 'fonts', 'colours' ];

const BG_DIR = '/usr/share/glinet-panel-ui/backgrounds';

const BACKGROUNDS = [
	'bg-1-vert-lines',
	'bg-2-horiz-lines',
	'bg-3-vert-waves',
	'bg-4-horiz-waves',
	'bg-5-diag-steep',
	'bg-6-diag-shallow',
	'bg-7-diag-waves-steep',
	'bg-8-diag-waves-shallow'
];

function background_load() {
	let which = settings.background;

	if (!which || which > length(BACKGROUNDS))
		return null;

	let path = sprintf('%s/%s.png', BG_DIR, BACKGROUNDS[which - 1]);
	let index = lv.image_load(path);

	if (index == null)
		warn(sprintf('panel: background %s could not be loaded\n', path));

	return index;
}

function boot_applet_retire() {
	let path = getenv('GLINET_PANEL_BOOT_PID');

	if (!path)
		return;

	let pid = readfile(path);

	if (pid)
		system([ 'kill', trim(pid) ]);

	unlink(path);
}

if (!lv.init())
	die('cannot initialise LVGL');

if (!lv.display_drm(getenv('PANEL_DRM_DEVICE') ?? '/dev/dri/card0', -1))
	die('cannot open the DRM display');

let touch_device = getenv('PANEL_TOUCH_DEVICE');

if (touch_device)
	lv.indev_evdev(touch_device);

runtime_init();

uloop.init();
sampler_init();

wan_device_read();

let names = settings.test_pages ? [ ...settings.pages, ...TEST_PAGES ]
				: [ ...settings.pages ];

const PAGES = pages_load(names, settings.sections);

for (let page in PAGES)
	if (index(TEST_PAGES, page.name) >= 0)
		page.test = true;

if (!length(PAGES))
	die('no pages could be loaded');

const LOCK = page_load('lock', null);

if (!LOCK)
	die('the lock page could not be loaded');

const PIN = settings.pin ? page_load('pin', null) : null;

if (settings.pin && !PIN)
	die('the pin page could not be loaded');

sampler_awake(true);
ui_build(PAGES, LOCK, PIN, settings.pin, background_load(), settings.scroll,
	 settings.clock_24h);

/* Draw and commit before the applet goes: until this frame is on the plane the
   applet's buffer is, and the kernel disables the CRTC to reclaim one in use. */
lv.refresh();

boot_applet_retire();

ui_seed();

runtime_start();

ubus.listener('network.interface', function() {
	wan_device_read();
	state.wan_ts = null;
});

function shot_path() {
	let now = localtime(time());

	return sprintf('%s/glinet-panel-screenshot-%04d%02d%02d-%02d%02d%02d.png',
		       SHOT_DIR, now.year, now.mon, now.mday,
		       now.hour, now.min, now.sec);
}

/* Held, or the handle is collected and the object goes with it. */
const LVGL_OBJ = ubus.publish('lvgl', {
	status: {
		call: function(req) {
			return view_status();
		},
		args: {}
	},

	page: {
		call: function(req) {
			runtime_wake();

			let name = req.args?.name ?? req.args?.index;

			if (!view_goto(name))
				return ubus.STATUS_NOT_FOUND;

			lv.refresh();

			return view_status();
		},
		args: { name: '', index: 0 }
	},

	open: {
		call: function(req) {
			runtime_wake();

			if (!view_open(req.args?.name, req.args?.params ?? {}))
				return ubus.STATUS_NOT_FOUND;

			lv.refresh();

			return view_status();
		},
		args: { name: '', params: {} }
	},

	back: {
		call: function(req) {
			view_back();
			lv.refresh();

			return view_status();
		},
		args: {}
	},

	wake: {
		call: function(req) {
			runtime_wake();
			lv.refresh();

			return view_status();
		},
		args: {}
	},

	screenshot: {
		call: function(req) {
			let path = req.args?.path ?? shot_path();

			lv.refresh();

			if (!lv.screenshot(path))
				return ubus.STATUS_UNKNOWN_ERROR;

			return { path };
		},
		args: { path: '' }
	}
});

uloop.run();
