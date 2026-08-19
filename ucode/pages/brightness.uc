'use strict';

import * as lv from 'lv';
import { C_SCREEN, C_SURFACE, C_FILL, GROUP_X, GROUP_W, BAR_H, BAR_RADIUS,
	 BAR_ICON, BAR_ICON_X, BAR_FILL_MIN } from '../lib/theme.uc';
import { icon_new, header_new } from '../lib/widget.uc';
import { body_new, centre } from '../lib/layout.uc';
import { IMAGE_SUN } from '../lib/assets.uc';

const RANGE_MIN	= 10;
const RANGE_MAX	= 100;

let brightness, activity;
let bar, fill;

function fill_width(pct) {
	let w = int(pct * GROUP_W / 100);

	return w > BAR_FILL_MIN ? w : BAR_FILL_MIN;
}

function fill_apply(pct) {
	fill.set({ w: fill_width(pct) });
}

function pct_at(x) {
	/* The touch point arrives in screen coordinates, so the bar's own left
	   edge comes off it, and it is clamped at both ends: a finger leaving
	   the bar sideways would otherwise read as a value beyond it. */
	let pct = int((x - GROUP_X) * 100 / GROUP_W);

	if (pct < RANGE_MIN)
		return RANGE_MIN;
	if (pct > RANGE_MAX)
		return RANGE_MAX;

	return pct;
}

function drag(code) {
	let point = lv.touch_point();

	if (!point)
		return;

	activity();

	let pct = pct_at(point.x);

	fill_apply(pct);
	brightness.set(pct);
}

function release(code) {
	activity();
	brightness.save();
}

function page_build(parent, ctx) {
	brightness = ctx.brightness;
	activity = ctx.activity;

	header_new(parent, 'Brightness', false, null);

	let body = body_new(parent, { dir: 'column', main: 'centre',
				      cross: 'centre' });

	bar = lv.obj(body);

	bar.set({ w: GROUP_W, h: BAR_H });
	bar.style({ bg_color: C_SURFACE, bg_opa: lv.OPA_COVER,
		    radius: BAR_RADIUS, border_width: 0, pad_all: 0 });
	bar.clickable(true);

	bar.scrollable(true);
	/* The bar keeps the horizontal drag to itself: lv_indev walks up for a
	   scrollable ancestor, and would otherwise page the roots under the
	   finger. Elastic and momentum come off so it does not rubber band. */
	bar.scroll_dir(lv.DIR_HOR);
	bar.flag('scroll_chain_hor', false);
	bar.flag('scroll_elastic', false);
	bar.flag('scroll_momentum', false);
	bar.scrollbar(lv.SCROLLBAR_OFF);

	/* Written live from the percentage, so it stays out of any layout. */
	fill = lv.obj(bar);

	fill.set({ x: 0, y: 0, w: GROUP_W, h: BAR_H });
	fill.style({ bg_color: C_FILL, bg_opa: lv.OPA_COVER,
		     radius: BAR_RADIUS, border_width: 0, pad_all: 0 });
	fill.clickable(false);
	fill.scrollable(false);

	icon_new(fill, IMAGE_SUN, C_SCREEN)
		.set({ x: BAR_ICON_X, y: centre(BAR_H, BAR_ICON) });

	bar.on(lv.EVENT_PRESSED, drag);
	bar.on(lv.EVENT_PRESSING, drag);
	bar.on(lv.EVENT_RELEASED, release);
}

function page_enter() {
	fill_apply(brightness.get());
}

return {
	needs: [],
	build: page_build,
	enter: page_enter
};
