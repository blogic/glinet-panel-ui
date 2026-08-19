'use strict';

import * as lv from 'lv';
import { C_SCREEN, C_IDLE, C_TXT_DIM, C_RAISED, C_TXT, W, H, DOT_SIZE, DOT_GAP,
	 DOT_BOTTOM, BACK_SIZE, BACK_X, BACK_Y, LOCK_SIZE, LOCK_X, LOCK_Y,
	 LOCK_HIT } from './theme.uc';
import { box_new } from './widget.uc';
import { subpage_load } from './loader.uc';
import { IMAGE_BACK, IMAGE_LOCK } from './assets.uc';
import { state, CHART_POINTS, source_subscribe, source_release, source_seed,
	 source_watch } from './sampler.uc';

let ctx;

const DOT_Y	= H - DOT_BOTTOM - DOT_SIZE;

const DEPTH_MAX	= 2;

const TILE_SPACER = 0;
const TILE_PAGE	= 1;

let pages = [];
let tiles = [];
let dots = [];
let layers = [];
let stack = [];
let screen, tileview, lock_page, lock_screen, pin_page, pin_screen;
let background;
let scroll_pages = true;
let active = 0;
let locked, pinning;
let activity_fn, wake_fn, defer_fn, idle_fn, brightness_fns;
let pending = [];

function activity_dispatch() {
	if (activity_fn)
		activity_fn();
}

function wake_dispatch() {
	/* The rest of the gesture is thrown away, or a swipe to wake carries on
	   into the root pager. */
	lv.touch_drop();

	if (wake_fn)
		wake_fn();
}

function idle_dispatch() {
	if (idle_fn)
		idle_fn();
}

function defer(work) {
	push(pending, work);

	if (defer_fn)
		defer_fn();
}

function view_current() {
	if (pinning)
		return pin_page;
	if (locked)
		return lock_page;

	return length(stack) ? stack[-1].page : pages[active];
}

function page_update(page, name) {
	if (!page?.update)
		return;
	if (index(page.needs, name) < 0)
		return;

	page.update(name);
}

function source_update(name, broadcast) {
	if (!broadcast) {
		page_update(view_current(), name);

		return;
	}

	for (let page in pages)
		page_update(page, name);

	page_update(lock_page, name);

	if (length(stack))
		page_update(stack[-1].page, name);
}

function page_leave(page) {
	if (page?.leave)
		page.leave();

	source_release(page.needs);
}

function page_enter(page) {
	source_subscribe(page.needs);

	if (page?.enter)
		page.enter();
}

function dots_refresh() {
	for (let i = 0; i < length(dots); i++)
		dots[i].style({ bg_color: i == active ? C_TXT_DIM : C_IDLE });
}

function chrome_refresh() {
	let deep = length(stack) > 0;

	for (let dot in dots)
		dot.hidden(deep);
}

function tile_changed() {
	let now = tileview.tile_active()?.col ?? 0;

	activity_dispatch();

	if (now == active)
		return;

	page_leave(pages[active]);
	active = now;
	page_enter(pages[active]);

	dots_refresh();
	chrome_refresh();
}

function root_swipe() {
	let dir = lv.gesture_dir();
	let step = 0;

	if (dir == lv.DIR_LEFT)
		step = 1;
	else if (dir == lv.DIR_RIGHT)
		step = -1;

	if (!step)
		return;

	activity_dispatch();

	if (locked || pinning || length(stack))
		return;

	let target = active + step;

	if (target < 0 || target >= length(pages))
		return;

	page_leave(pages[active]);
	active = target;
	tileview.tile_set(target, 0, false);

	page_enter(pages[active]);
	dots_refresh();
	chrome_refresh();
}

function dir_for(pos, count) {
	if (count < 2)
		return lv.DIR_NONE;
	if (pos == 0)
		return lv.DIR_RIGHT;
	if (pos == count - 1)
		return lv.DIR_LEFT;

	return lv.DIR_HOR;
}

/* Call before the parent's content: z order is creation order and LVGL 9.3 has
   no lv_obj_move_foreground(). */
function background_build(parent) {
	if (background == null)
		return null;

	let image = lv.image(parent);

	image.src(background);
	image.set({ x: 0, y: 0 });
	image.clickable(false);

	return image;
}

function layer_teardown(depth) {
	let entry = stack[depth - 1];

	if (!entry)
		return;

	page_leave(entry.page);
	splice(stack, depth - 1);

	entry.layer.content.clean();
	entry.layer.obj.hidden(true);

	page_enter(view_current());
	chrome_refresh();
}

function layer_new(depth) {
	let obj = lv.tileview(screen);

	obj.set({ x: 0, y: 0, w: W, h: H });
	obj.style({ bg_opa: lv.OPA_TRANSP, border_width: 0, pad_all: 0 });
	obj.scrollbar(lv.SCROLLBAR_OFF);

	/* Clear the flag on the layer, never the direction on the content tile:
	   the tileview rewrites its own scroll_dir on every SCROLL_END, and back
	   then takes three presses. */
	obj.scrollable(false);

	let spacer = obj.tile_add(TILE_SPACER, 0, lv.DIR_NONE);

	spacer.style({ bg_opa: lv.OPA_TRANSP, border_width: 0, pad_all: 0 });
	spacer.scrollbar(lv.SCROLLBAR_OFF);
	spacer.scrollable(false);

	let content = obj.tile_add(TILE_PAGE, 0, lv.DIR_LEFT);

	content.style({ bg_color: C_SCREEN, bg_opa: lv.OPA_COVER,
		        border_width: 0,
			pad_all: 0 });
	content.scrollbar(lv.SCROLLBAR_OFF);
	content.scrollable(false);
	content.on(lv.EVENT_PRESSED, activity_dispatch);

	obj.hidden(true);

	return { obj, spacer, content };
}

function nav_back() {
	if (!length(stack))
		return;

	defer(function() {
		let depth = length(stack);

		if (!depth)
			return;

		stack[depth - 1].layer.obj.tile_set(TILE_SPACER, 0, false);
		layer_teardown(depth);
	});
}

function lock_build(parent) {
	let hit = lv.obj(parent);

	hit.set({ x: W - LOCK_HIT, y: 0, w: LOCK_HIT, h: LOCK_HIT });
	hit.style({ bg_opa: lv.OPA_TRANSP, border_width: 0, pad_all: 0,
		    radius: 0 });
	hit.clickable(true);
	hit.scrollable(false);

	let mark = lv.image(hit);

	mark.src(IMAGE_LOCK);
	mark.style({ image_recolor: C_TXT, image_recolor_opa: lv.OPA_COVER });
	mark.set({ x: LOCK_X - (W - LOCK_HIT), y: LOCK_Y });
	mark.clickable(false);

	hit.on(lv.EVENT_CLICKED, function() {
		activity_dispatch();
		defer(idle_dispatch);
	});

	return hit;
}

function back_build(parent) {
	let obj = lv.obj(parent);

	obj.set({ x: BACK_X, y: BACK_Y, w: BACK_SIZE, h: BACK_SIZE });
	obj.style({ bg_color: C_RAISED, bg_opa: lv.OPA_COVER,
		    radius: int(BACK_SIZE / 2) + 1, border_width: 0, pad_all: 0 });
	obj.clickable(true);
	obj.scrollable(false);

	let mark = lv.image(obj);

	mark.src(IMAGE_BACK);
	mark.style({ image_recolor: C_TXT, image_recolor_opa: lv.OPA_COVER });
	/* A chevron points away from its optical centre, so nudge it back. */
	mark.set({ align: lv.ALIGN_CENTER, align_x: -1 });
	mark.clickable(false);

	obj.on(lv.EVENT_CLICKED, function() {
		activity_dispatch();
		nav_back();
	});

	return obj;
}

function nav_open(name, params) {
	let depth = length(stack) + 1;

	if (depth > DEPTH_MAX) {
		warn(sprintf('panel: %s is past the depth cap\n', name));

		return false;
	}

	let page = subpage_load(name);

	if (!page)
		return false;

	let layer = layers[depth - 1];

	layer.content.clean();

	background_build(layer.content);

	page.build(layer.content, { ...ctx, config: null, params });
	back_build(layer.content);
	lock_build(layer.content);

	page_leave(view_current());

	layer.obj.hidden(false);
	layer.obj.tile_set(TILE_PAGE, 0, false);

	push(stack, { page, layer });

	page_enter(page);
	chrome_refresh();

	return true;
}

function dots_build(count) {
	let left = int((W - ((count - 1) * DOT_GAP + DOT_SIZE)) / 2);

	for (let i = 0; i < count; i++) {
		let dot = box_new(screen, C_IDLE, DOT_SIZE);

		dot.set({ x: left + i * DOT_GAP, y: DOT_Y,
			  w: DOT_SIZE, h: DOT_SIZE });

		push(dots, dot);
	}
}

function screen_new() {
	let obj = lv.screen_create();

	obj.style({ bg_color: C_SCREEN, border_width: 0, pad_all: 0 });
	obj.scrollbar(lv.SCROLLBAR_OFF);
	obj.scrollable(false);

	return obj;
}

function tiles_build() {
	let count = length(pages);

	for (let i = 0; i < count; i++) {
		let tile = tileview.tile_add(i, 0, dir_for(i, count));

		tile.style({ bg_opa: lv.OPA_TRANSP, border_width: 0, pad_all: 0 });
		tile.scrollbar(lv.SCROLLBAR_OFF);
		tile.scrollable(false);

		if (pages[i].test)
			tile.style({ bg_color: C_SCREEN,
				     bg_opa: lv.OPA_COVER });

		tile.on(lv.EVENT_PRESSED, activity_dispatch);

		push(tiles, tile);
	}

	for (let i = 0; i < count; i++) {
		pages[i].build(tiles[i], { ...ctx, config: pages[i].config });

		if (!pages[i].test)
			lock_build(tiles[i]);
	}
}

function stack_unwind() {
	while (length(stack)) {
		let entry = pop(stack);

		entry.layer.content.clean();
			entry.layer.obj.hidden(true);
		entry.layer.obj.tile_set(TILE_SPACER, 0, false);
	}
}

function pin_unlock() {
	page_leave(pin_page);
	pinning = false;

	stack_unwind();

	active = 0;
	tileview.tile_set(0, 0, false);

	page_enter(pages[active]);
	dots_refresh();
	chrome_refresh();

	lv.screen_load(screen);
}

/**
 * activity_watch - register the handler that defers the idle lock
 * @fn: called on every touch the panel sees
 */
export function activity_watch(fn) {
	activity_fn = fn;
};

/**
 * wake_watch - register the handler that brings the panel out of idle
 * @fn: called on a touch of the idle screen
 */
export function wake_watch(fn) {
	wake_fn = fn;
};

/**
 * defer_watch - register the handler that drains the deferred work queue
 * @fn: called when work has been queued, and must run it outside LVGL
 */
export function defer_watch(fn) {
	defer_fn = fn;
};

/**
 * idle_watch - register the handler that puts the panel back to idle
 * @fn: called by the lock button
 */
export function idle_watch(fn) {
	idle_fn = fn;
};

/**
 * brightness_watch - register the backlight control the pages are handed
 * @fns: get, set and save, which the brightness page reaches through ctx
 */
export function brightness_watch(fns) {
	brightness_fns = fns;
};

/**
 * nav_flush - run the work queued by defer()
 *
 * Call from uloop, never from inside lv_timer_handler().
 */
export function nav_flush() {
	let work = pending;

	pending = [];

	for (let fn in work)
		fn();
};

/**
 * ui_build - build every screen, and show the idle one
 * @page_list: the root pages, in order
 * @lock: the idle page
 * @pin: the keypad page, built only when @pin_code is set
 * @pin_code: the configured PIN, or null
 * @bg: a background image handle, or null
 * @scroll: true to swipe between roots, false to change page in one step
 * @clock_24h: the format the idle clock is drawn in
 */
export function ui_build(page_list, lock, pin, pin_code, bg, scroll, clock_24h) {
	pages = page_list;
	lock_page = lock;
	pin_page = pin_code ? pin : null;
	background = bg;
	scroll_pages = scroll;

	ctx = { state, points: CHART_POINTS, activity: activity_dispatch,
		open: nav_open, back: nav_back, defer,
		brightness: {
			get: function() {
				return brightness_fns?.get() ?? 100;
			},
			set: function(pct) {
				brightness_fns?.set(pct);
			},
			save: function() {
				brightness_fns?.save();
			}
		} };

	screen = screen_new();

	background_build(screen);

	tileview = lv.tileview(screen);

	tileview.set({ x: 0, y: 0, w: W, h: H });
	tileview.style({ bg_opa: lv.OPA_TRANSP, border_width: 0, pad_all: 0 });
	tileview.scrollbar(lv.SCROLLBAR_OFF);
	tileview.on(lv.EVENT_VALUE_CHANGED, tile_changed);

	if (!scroll_pages) {
		tileview.scrollable(false);
		screen.on(lv.EVENT_GESTURE, root_swipe);
	}

	tiles_build();

	dots_build(length(pages));

	for (let depth = 1; depth <= DEPTH_MAX; depth++)
		push(layers, layer_new(depth));

	lock_screen = screen_new();
	lock_screen.on(lv.EVENT_PRESSED, wake_dispatch);
	background_build(lock_screen);
	lock_page.build(lock_screen, { ...ctx, config: lock_page.config,
				       clock_24h });

	if (pin_page) {
		pin_screen = screen_new();
		background_build(pin_screen);
		pin_page.build(pin_screen, { ...ctx, config: null,
					     pin: pin_code,
					     unlock: function() {
						defer(pin_unlock);
					     } });
	}

	source_watch(source_update);

	locked = true;
	page_enter(lock_page);
	dots_refresh();

	lv.screen_load(lock_screen);
};

/**
 * ui_seed - read every source a page declares, then draw every page once
 *
 * A page is only entered when a swipe settles, so without this a first visit
 * shows an empty page for the length of the gesture.
 */
export function ui_seed() {
	let names = [];

	for (let page in pages)
		for (let need in page.needs)
			if (index(names, need) < 0)
				push(names, need);

	source_seed(names);

	for (let page in pages)
		page.enter?.();
};

/**
 * view_status - what the panel is showing
 *
 * Return: locked, pin, depth, index, page, root and the page names.
 */
export function view_status() {
	let names = [];

	for (let page in pages)
		push(names, page.name);

	return {
		locked: !!locked,
		pin: !!pinning,
		depth: length(stack),
		index: active,
		page: length(stack) ? stack[-1].page.name : pages[active]?.name,
		root: pages[active]?.name,
		pages: names
	};
};

/**
 * view_goto - show a root page
 * @which: a page name or its index
 *
 * Drops any open sub page and leaves the idle screen. Call from uloop.
 *
 * Return: false if no root answers to @which.
 */
export function view_goto(which) {
	let target = -1;

	for (let i = 0; i < length(pages); i++)
		if (pages[i].name == which || i == which)
			target = i;

	if (target < 0)
		return false;

	page_leave(view_current());
	stack_unwind();

	locked = false;
	pinning = false;
	active = target;
	tileview.tile_set(target, 0, false);

	page_enter(pages[active]);
	dots_refresh();
	chrome_refresh();

	lv.screen_load(screen);

	return true;
};

/**
 * view_open - open a sub page
 * @name: the file name under subpages/
 * @params: handed to the page as ctx.params
 *
 * Return: whether this call opened it, not whether anything is open.
 */
export function view_open(name, params) {
	return nav_open(name, params);
};

/**
 * view_back - close the open sub page
 *
 * Return: false when nothing was open.
 */
export function view_back() {
	if (!length(stack))
		return false;

	stack[-1].layer.obj.tile_set(TILE_SPACER, 0, false);
	layer_teardown(length(stack));

	return true;
};

/**
 * view_lock - show the idle screen
 */
export function view_lock() {
	page_leave(view_current());
	locked = true;
	pinning = false;
	page_enter(lock_page);

	lv.screen_load(lock_screen);
};

/**
 * view_pin - show the keypad
 *
 * Return: false when no PIN is configured, so the caller goes to the roots.
 */
export function view_pin() {
	if (!pin_page)
		return false;

	page_leave(view_current());
	locked = false;
	pinning = true;
	page_enter(pin_page);

	lv.screen_load(pin_screen);

	return true;
};

/**
 * view_wake - leave the idle screen for the first root
 *
 * The stack is unwound: a sub page is where the user navigated to minutes ago,
 * not where they expect to arrive.
 */
export function view_wake() {
	page_leave(view_current());
	locked = false;
	pinning = false;

	stack_unwind();

	active = 0;
	tileview.tile_set(0, 0, false);

	page_enter(pages[active]);
	dots_refresh();
	chrome_refresh();

	lv.screen_load(screen);
};
