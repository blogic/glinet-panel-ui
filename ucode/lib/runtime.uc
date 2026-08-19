'use strict';

import * as lv from 'lv';
import * as uci from 'uci';
import * as uloop from 'uloop';
import { writefile, glob, readfile } from 'fs';
import { monotonic, sampler_awake } from './sampler.uc';
import { view_lock, view_wake, view_pin, activity_watch, wake_watch,
	 defer_watch, idle_watch, brightness_watch,
	 nav_flush } from './page.uc';

const ST_AWAKE	= 0;
const ST_LOCKED	= 1;

const LOCK_DEFAULT = 5;
const LOCK_MIN	= 1;
const LOCK_MAX	= 30;

const IDLE_BLANK = 'blank';
const IDLE_ON	= 'on';
const IDLE_MODES = [ IDLE_BLANK, IDLE_ON ];

const UCI_TRUE	= [ '1', 'on', 'true', 'yes', 'enabled' ];

const BRIGHT_MIN = 10;
const BRIGHT_MAX = 100;

const BG_NONE	= 0;
const BG_MAX	= 8;

const SECONDS_PER_MINUTE = 60;

const TICK_MIN_AWAKE	= 5;
const TICK_MIN_LOCKED	= 50;
const TICK_MAX		= 200;
const MS_IDLE		= 1000;

const PAGES_DEFAULT = [ 'traffic', 'system' ];

export const settings = {
	auto_lock: LOCK_DEFAULT,
	pin: null,
	brightness: null,
	background: BG_NONE,
	clock_24h: true,
	scroll: true,
	idle_mode: IDLE_ON,
	test_pages: false,
	pages: PAGES_DEFAULT,
	sections: {}
};

let backlight = { path: null, max: 0 };
let level = BRIGHT_MAX;
let mode = ST_LOCKED;
let touched = 0;
let wake_pending;
let lit = true;
let timers = {};

function raw_for(pct) {
	let raw = int(pct * backlight.max / 100);

	return raw > 0 ? raw : 1;
}

function backlight_set(on) {
	lit = on;

	if (backlight.path)
		writefile(backlight.path,
			  sprintf('%d', on ? raw_for(level) : 0));
}

function brightness_clamp(pct) {
	if (pct < BRIGHT_MIN)
		return BRIGHT_MIN;
	if (pct > BRIGHT_MAX)
		return BRIGHT_MAX;

	return pct;
}

function backlight_init() {
	let found = glob('/sys/class/backlight/*');

	if (!length(found))
		return;

	let max = readfile(found[0] + '/max_brightness');

	if (max == null)
		return;

	backlight.path = found[0] + '/brightness';
	backlight.max = +trim(max);

	/* Not zero: SIGTERM writes it, so a restart would inherit the dark panel. */
	let now = +trim(readfile(found[0] + '/brightness') ?? '0');

	if (now > 0 && backlight.max > 0)
		level = brightness_clamp(int(now * 100 / backlight.max));
}

function brightness_set(pct) {
	level = brightness_clamp(pct);

	if (lit)
		backlight_set(true);
}

function brightness_get() {
	return level;
}

function brightness_save() {
	let cursor = uci.cursor();

	if (!cursor.load('glinet_panel'))
		return;

	cursor.set('glinet_panel', '@panel[0]', 'brightness', sprintf('%d', level));
	cursor.commit('glinet_panel');
}

function settings_read() {
	let cursor = uci.cursor();

	if (!cursor.load('glinet_panel'))
		return;

	let lock = +cursor.get('glinet_panel', '@panel[0]', 'auto_lock');

	if (lock >= LOCK_MIN && lock <= LOCK_MAX)
		settings.auto_lock = lock;

	let idle = cursor.get('glinet_panel', '@panel[0]', 'idle_mode');

	if (index(IDLE_MODES, idle) >= 0)
		settings.idle_mode = idle;

	let pin = cursor.get('glinet_panel', '@panel[0]', 'pin');

	if (type(pin) == 'string' && match(pin, /^[0-9]{6}$/))
		settings.pin = pin;
	else if (pin)
		warn('panel: pin must be six digits, ignoring it\n');

	let bright = cursor.get('glinet_panel', '@panel[0]', 'brightness');

	if (bright != null && bright != '')
		settings.brightness = brightness_clamp(+bright);

	let bg = +cursor.get('glinet_panel', '@panel[0]', 'background');

	if (bg >= BG_NONE && bg <= BG_MAX)
		settings.background = bg;

	let scroll = cursor.get('glinet_panel', '@panel[0]', 'scroll');

	if (scroll != null && scroll != '')
		settings.scroll = (scroll == '1');

	let clock = cursor.get('glinet_panel', '@panel[0]', 'clock_24h');

	if (clock != null && clock != '')
		settings.clock_24h = (index(UCI_TRUE, lc(clock)) >= 0);

	settings.test_pages = (cursor.get('glinet_panel', '@panel[0]', 'test_pages') == '1');

	let listed = cursor.get('glinet_panel', '@panel[0]', 'pages');

	if (type(listed) == 'array' && length(listed))
		settings.pages = listed;

	let sections = {};

	cursor.foreach('glinet_panel', 'page', function(section) {
		if (section.name)
			sections[section.name] = section;
	});

	settings.sections = sections;
}

function activity_mark() {
	touched = monotonic();
}

function lock_enter() {
	if (mode != ST_AWAKE)
		return;

	mode = ST_LOCKED;

	if (settings.idle_mode == IDLE_BLANK)
		backlight_set(false);

	view_lock();
	sampler_awake(settings.idle_mode == IDLE_ON);
	lv.refresh();
}

function wake_run() {
	wake_pending = false;
	mode = ST_AWAKE;

	sampler_awake(true);

	if (!settings.pin || !view_pin())
		view_wake();

	lv.refresh();
	backlight_set(true);
}

/* Bounced through uloop: this runs inside lv_timer_handler(), which must not
   load a screen. */
function wake_request() {
	activity_mark();

	if (mode == ST_AWAKE || wake_pending)
		return;

	wake_pending = true;
	timers.wake.set(0);
}

function idle_check() {
	if (monotonic() - touched < settings.auto_lock * SECONDS_PER_MINUTE)
		return;

	if (mode == ST_AWAKE) {
		lock_enter();

		return;
	}

	if (!lit || settings.idle_mode != IDLE_BLANK)
		return;

	backlight_set(false);
	sampler_awake(false);
}

function tick() {
	let delay = lv.timer_handler();
	let floor = mode == ST_AWAKE ? TICK_MIN_AWAKE : TICK_MIN_LOCKED;

	if (delay < floor)
		delay = floor;
	else if (delay > TICK_MAX)
		delay = TICK_MAX;

	timers.tick.set(delay);
}

/**
 * runtime_wake - bring the panel up now, without the deferral
 *
 * For a caller already outside lv_timer_handler, such as the ubus object.
 */
export function runtime_wake() {
	if (mode == ST_AWAKE) {
		activity_mark();

		return;
	}

	wake_run();
};

/**
 * runtime_init - read the settings and find the backlight
 *
 * Fills settings, which the caller reads to build the ui.
 */
export function runtime_init() {
	settings_read();
	backlight_init();

	if (settings.brightness != null)
		level = settings.brightness;
};

/**
 * runtime_start - wire the page framework to uloop and arm the timers
 *
 * Registers the activity, wake, idle, defer and brightness handlers, then
 * starts the tick. Call after runtime_init() and after the ui is built.
 */
export function runtime_start() {
	activity_watch(activity_mark);
	wake_watch(wake_request);
	idle_watch(lock_enter);

	defer_watch(function() {
		timers.nav.set(0);
	});

	brightness_watch({ get: brightness_get, set: brightness_set,
			   save: brightness_save });

	timers.tick = uloop.timer(TICK_MIN_AWAKE, tick);
	timers.wake = uloop.timer(-1, wake_run);
	timers.nav = uloop.timer(-1, nav_flush);
	timers.idle = uloop.interval(MS_IDLE, idle_check);

	uloop.signal('SIGTERM', function() {
		backlight_set(false);
		uloop.end();
	});

	activity_mark();
	backlight_set(true);
};
