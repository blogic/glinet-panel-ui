'use strict';

import * as lv from 'lv';
import * as uci from 'uci';
import { FONT_TNUM_12, FONT_TNUM_10, FONT_REG_15, FONT_REG_11, FONT_SEMI_21,
	 FONT_SEMI_15, FONT_REG_13, IMAGE_CHEVRON, IMAGE_EYE,
	 IMAGE_EYE_OFF } from './assets.uc';
import { C_SCREEN, C_SURFACE, C_RULE, C_TXT, C_ACTION, CARD_X, CARD_W,
	 CARD_PAD, CARD_RADIUS, SEP_H, C_TXT_DIM, C_RAISED, C_IDLE, C_DOWN,
	 C_OK, C_ALERT, H, GROUP_X, GROUP_W, GROUP_RADIUS, ROW_H, ROW_PAD,
	 ROW_GAP, HEAD_TOP, HEAD_X, HEAD_BOTTOM, HEAD_INDENT,
	 HEAD_H as HEAD_H_THEME, LIST_H } from './theme.uc';

/* It belongs to the grid in theme.uc now. Still exported from here, because
   four pages already take it from here. */
export const HEAD_H = HEAD_H_THEME;

let activity;

const BAR_GAP	 = 2;
const BAR_RADIUS = 1;

export const BAR_SCALE = 1000;

const BAR_MIN_PX = 2;

/**
 * bar_scaled - map a raw reading onto the fixed chart axis
 * @value: the sample
 * @full: the value that reads as full scale
 * @height: bar height in pixels, for a floor under the result, or null for a
 *          line chart, where a floor would lift the trace off the baseline
 *
 * Charts keep a 0 to BAR_SCALE axis because LVGL maps a point with an int32
 * multiply, which overflows above about 46 MB/s.
 *
 * Return: a value between 0 and BAR_SCALE.
 */
export function bar_scaled(value, full, height) {
	if (full <= 0)
		return 0;

	let scaled = int(value * BAR_SCALE / full);

	if (scaled > BAR_SCALE)
		scaled = BAR_SCALE;

	if (height == null)
		return scaled;

	let floor = int((BAR_MIN_PX * BAR_SCALE + height - 1) / height);

	return scaled > floor ? scaled : floor;
};

/**
 * label_new - a plain label
 * @parent: object to build it on
 * @font: a face from assets.uc
 * @colour: a colour from theme.uc
 * @text: the string
 *
 * Return: the label object.
 */
export function label_new(parent, font, colour, text) {
	let label = lv.label(parent);

	label.text(text);
	label.style({ text_color: colour, text_font: font });

	return label;
};

/**
 * text_new - a label that can be updated with text_set()
 * @parent: object to build it on
 * @font: a face from assets.uc
 * @colour: a colour from theme.uc
 * @text: the initial string
 *
 * Return: an entry of obj and last.
 */
export function text_new(parent, font, colour, text) {
	return { obj: label_new(parent, font, colour, text), last: text };
};

/**
 * empty_new - the one line a list shows in place of no rows
 * @parent: the scroll area
 * @text: what there is none of
 *
 * Return: the label object, indented to the row text column.
 */
export function empty_new(parent, text) {
	let label = label_new(parent, FONT_REG_13, C_TXT, text);

	label.set({ x: GROUP_X + ROW_PAD, y: 0 });

	return label;
};

/**
 * text_set - write a label only when the string changed
 * @entry: an entry from text_new()
 * @text: the new string
 */
export function text_set(entry, text) {
	if (entry.last == text)
		return;

	entry.last = text;
	entry.obj.text(text);
};

/**
 * box_new - a filled rectangle
 * @parent: object to build it on
 * @colour: the fill
 * @radius: corner radius
 *
 * Not clickable, so it cannot swallow a press the tile needs.
 *
 * Return: the object. The caller sets its geometry.
 */
export function box_new(parent, colour, radius) {
	let box = lv.obj(parent);

	box.style({ bg_color: colour, radius, border_width: 0, pad_all: 0 });
	box.clickable(false);
	box.scrollable(false);

	return box;
};

/**
 * outline_new - a 1 px outlined rectangle with no fill
 * @parent: object to build it on
 * @colour: the border
 *
 * Return: the object. The caller sets its geometry.
 */
export function outline_new(parent, colour) {
	let box = lv.obj(parent);

	box.style({ bg_opa: lv.OPA_TRANSP, border_width: 1, border_color: colour,
		    radius: 0, pad_all: 0 });
	box.clickable(false);
	box.scrollable(false);

	return box;
};

/**
 * card_new - the full bleed container a chart or gauge page sits on
 * @parent: the page tile
 * @y: top edge
 * @h: height
 *
 * Padding is zero; children offset themselves by CARD_PAD.
 *
 * Return: the card object.
 */
export function card_new(parent, y, h) {
	let card = lv.obj(parent);

	card.set({ x: CARD_X, y, w: CARD_W, h });
	card.style({ bg_color: C_SURFACE, bg_opa: lv.OPA_COVER, radius: CARD_RADIUS,
		     border_width: 0, pad_all: 0 });
	card.clickable(false);
	card.scrollable(false);

	return card;
};

/**
 * bars_new - a bar chart
 * @parent: object to build it on
 * @colour: the series colour
 * @x: left edge
 * @y: top edge
 * @w: width
 * @h: height
 * @points: how many bars
 *
 * Values run 0 to BAR_SCALE; normalise with bar_scaled().
 *
 * Return: the chart object.
 */
export function bars_new(parent, colour, x, y, w, h, points) {
	let chart = lv.chart(parent);

	chart.set({ x, y, w, h });
	chart.chart_type(lv.CHART_TYPE_BAR);
	chart.point_count(points);
	chart.update_mode(lv.CHART_UPDATE_SHIFT);
	chart.div_lines(0, 0);
	chart.scrollbar(lv.SCROLLBAR_OFF);
	chart.clickable(false);
	chart.scrollable(false);
	chart.style({ bg_opa: lv.OPA_TRANSP, border_width: 0, pad_all: 0,
		      pad_column: BAR_GAP });
	chart.style({ width: 0, height: 0 }, lv.PART_INDICATOR);
	chart.style({ bg_color: colour, bg_opa: lv.OPA_COVER,
		      radius: BAR_RADIUS }, lv.PART_ITEMS);
	chart.chart_range(0, BAR_SCALE);
	chart.series(colour);

	return chart;
};

/**
 * sep_new - a hairline across a card, inset at both ends
 * @card: the card
 * @y: top edge
 *
 * Return: the hairline object.
 */
export function sep_new(card, y) {
	let sep = box_new(card, C_RULE, 0);

	sep.set({ x: CARD_PAD, y, w: CARD_W - 2 * CARD_PAD, h: SEP_H });

	return sep;
};

/**
 * scroll_new - a transparent area that scrolls its children vertically
 * @parent: object to build it on
 * @x: left edge
 * @y: top edge
 * @w: width
 * @h: height
 *
 * Vertical only, so a horizontal swipe still reaches the tileview. The caller
 * owes an activity handler, since this swallows the press.
 *
 * Return: the area object.
 */
export function scroll_new(parent, x, y, w, h) {
	let area = lv.obj(parent);

	area.set({ x, y, w, h });
	area.style({ bg_opa: lv.OPA_TRANSP, border_width: 0, pad_all: 0,
		     radius: 0 });

	/* Clickable, or it never scrolls: lv_obj_hit_test() rejects anything
	   without the flag, so the press never reaches a scrollable ancestor. */
	area.clickable(true);
	area.scrollable(true);
	area.scroll_dir(lv.DIR_VER);
	area.scrollbar(lv.SCROLLBAR_AUTO);

	return area;
};

/* Read from the faces rather than copied out of them. */
const LINE_UNIT		= lv.font_line_height(FONT_REG_13);
const LINE_CAPTION	= lv.font_line_height(FONT_REG_11);
const LINE_BODY_H	= lv.font_line_height(FONT_REG_15);
const LINE_ADDR		= lv.font_line_height(FONT_TNUM_12);
const LINE_ADDR_SM	= lv.font_line_height(FONT_TNUM_10);
const LINE_GAP		= 1;

const TIER_LARGE = { label: FONT_REG_15, label_h: LINE_BODY_H,
		     second: FONT_REG_13, second_h: LINE_UNIT };
const TIER_SMALL = { label: FONT_REG_13, label_h: LINE_UNIT,
		     second: FONT_REG_11, second_h: LINE_CAPTION };

const DOT_R		= 7;
const ICON_SLOT		= 22;
const ICON_H		= 17;
const CHEVRON		= 24;
const EYE		= 16;

const SWITCH_W		= 38;
const SWITCH_H		= 22;
const KNOB		= 18;
const KNOB_PAD		= 2;

/**
 * icon_new - draw a coverage mark in a colour
 * @parent: object to build it on
 * @image: an IMAGE_ handle from assets.uc
 * @colour: what to tint it
 *
 * Return: the image object. The caller sets its position.
 */
export function icon_new(parent, image, colour) {
	let icon = lv.image(parent);

	icon.src(image);
	icon.style({ image_recolor: colour, image_recolor_opa: lv.OPA_COVER });
	icon.clickable(false);

	return icon;
};

/**
 * header_new - the page title
 * @parent: the page tile
 * @title: the name of the page
 * @indented: true on a sub page, to clear the back circle
 * @count: a tally set beside the title, or null
 *
 * Return: the title label.
 */
export function header_new(parent, title, indented, count) {
	let x = indented ? HEAD_INDENT : HEAD_X;
	let label = label_new(parent, FONT_SEMI_21, C_TXT, title);

	label.set({ x, y: HEAD_TOP });

	if (count == null)
		return label;

	let after = x + lv.text_width(FONT_SEMI_21, title) + 5;
	let tally = label_new(parent, FONT_REG_13, C_RULE, count);

	tally.set({ x: after,
		    y: HEAD_TOP + lv.font_line_height(FONT_SEMI_21) - LINE_UNIT - 2 });

	return label;
};

const GROUP_OPA_MAX = 128;

let group_opa;

/**
 * card_opacity - how solid a card fill is, from uci list_opacity
 *
 * Read once per page. 100 is half opacity, not solid.
 *
 * Return: an LVGL opacity, OPA_COVER when the option is absent.
 */
export function card_opacity() {
	if (group_opa != null)
		return group_opa;

	group_opa = lv.OPA_COVER;

	let cursor = uci.cursor();

	if (!cursor.load('glinet_panel'))
		return group_opa;

	let raw = cursor.get('glinet_panel', '@panel[0]', 'list_opacity');

	if (raw == null || raw == '')
		return group_opa;

	let pct = +raw;

	if (pct >= 0 && pct <= 100)
		group_opa = int(pct * GROUP_OPA_MAX / 100);

	return group_opa;
}

/**
 * group_new - the inset rounded surface a list of rows sits on
 * @parent: the page's scroll area
 * @y: top edge
 * @h: the height the rows need, from rows_height()
 *
 * Bounded by the page: where @h is more than the space left, the group takes
 * that space and its rows scroll inside it.
 *
 * Return: the group object.
 */
export function group_new(parent, y, h, on_activity) {
	let group = lv.obj(parent);
	let room = parent.height() - y;
	let scrolls = h > room;
	/* Taken as an argument where the caller has one. Reading it from module
	   state means a group built before the page's list_new() silently gets
	   the previous page's handler, and the panel then blanks under the
	   finger, minutes later, on that page only. */
	let act = on_activity ?? activity;

	group.set({ x: GROUP_X, y, w: GROUP_W, h: scrolls ? room : h });
	group.style({ bg_color: C_SURFACE, bg_opa: card_opacity(),
		      radius: GROUP_RADIUS, border_width: 0, pad_all: 0,
		      clip_corner: true });
	/* Clickable, or it never scrolls. An information row carries no tap
	   handler, so a drag starting on one would otherwise reach nothing. */
	group.clickable(scrolls);
	group.scrollable(scrolls);

	if (!scrolls)
		return group;

	group.scroll_dir(lv.DIR_VER);
	group.scrollbar(lv.SCROLLBAR_AUTO);
	group.on(lv.EVENT_PRESSED, function() {
		act?.();
	});

	return group;
};

/**
 * row_sep_new - the hairline between two rows
 * @group: the group
 * @y: top edge
 *
 * Return: the hairline object.
 */
export function row_sep_new(group, y) {
	let sep = box_new(group, C_RULE, 0);

	sep.set({ x: ROW_PAD, y, w: GROUP_W - 2 * ROW_PAD, h: SEP_H });

	return sep;
};

/**
 * dot_new - a status dot
 * @parent: object to build it on
 * @x: left edge
 * @y: top edge
 * @up: true for green, false for the down colour
 *
 * Return: the dot object.
 */
export function dot_new(parent, x, y, up) {
	let dot = box_new(parent, up ? C_OK : C_DOWN, int(DOT_R / 2) + 1);

	dot.set({ x, y, w: DOT_R, h: DOT_R });

	return dot;
};

/**
 * switch_new - a track and a knob, thrown without animating
 * @parent: object to build it on
 * @x: left edge
 * @y: top edge
 * @on: the initial state
 * @on_change: called with the new state after a tap
 *
 * Return: a handle carrying on and set().
 */
export function switch_new(parent, x, y, on, on_change) {
	let track = lv.obj(parent);

	track.set({ x, y, w: SWITCH_W, h: SWITCH_H });
	track.style({ bg_color: on ? C_OK : C_IDLE, bg_opa: lv.OPA_COVER,
		      radius: int(SWITCH_H / 2), border_width: 0, pad_all: 0 });
	track.clickable(true);
	track.scrollable(false);

	let knob = box_new(track, C_TXT, int(KNOB / 2));

	knob.set({ x: on ? SWITCH_W - KNOB - KNOB_PAD : KNOB_PAD, y: KNOB_PAD,
		   w: KNOB, h: KNOB });

	let sw = { on };

	sw.set = function(value) {
		sw.on = value;

		track.style({ bg_color: value ? C_OK : C_IDLE });
		knob.set({ x: value ? SWITCH_W - KNOB - KNOB_PAD : KNOB_PAD });
	};

	track.on(lv.EVENT_PRESSED, function() {
		activity?.();
	});

	track.on(lv.EVENT_CLICKED, function() {
		sw.set(!sw.on);

		if (on_change)
			on_change(sw.on);
	});

	return sw;
};

const SIG_BARS	= 4;
const SIG_W	= 3;
const SIG_GAP	= 2;
const SIG_STEP	= 3;
const SIG_W_ALL	= SIG_BARS * SIG_W + (SIG_BARS - 1) * SIG_GAP;

/**
 * signal_new - four bars rising left to right
 * @parent: object to build it on
 * @x: left edge
 * @y: top edge
 * @level: how many bars are lit, 0 to 4
 *
 * Return: a handle carrying level and set(), so a page can relight the bars
 * without rebuilding the row.
 */
export function signal_new(parent, x, y, level) {
	let bars = [];

	for (let i = 0; i < SIG_BARS; i++) {
		let h = (i + 1) * SIG_STEP;
		let bar = box_new(parent, i < level ? C_TXT : C_IDLE, 1);

		bar.set({ x: x + i * (SIG_W + SIG_GAP),
			  y: y + SIG_BARS * SIG_STEP - h, w: SIG_W, h });

		push(bars, bar);
	}

	let signal = { level };

	signal.set = function(value) {
		if (signal.level == value)
			return;

		signal.level = value;

		for (let i = 0; i < SIG_BARS; i++)
			bars[i].style({ bg_color: i < value ? C_TXT : C_IDLE });
	};

	return signal;
};

/**
 * signal_level - how many bars a reading lights
 * @dbm: the signal, or null
 *
 * Return: 0 for no reading, otherwise 1 to 4.
 */
export function signal_level(dbm) {
	if (dbm == null)
		return 0;
	if (dbm >= -55)
		return 4;
	if (dbm >= -65)
		return 3;
	if (dbm >= -75)
		return 2;

	return 1;
};

function row_accessory(row, entry, kind, opts, h) {
	if (kind == 'chevron') {
		icon_new(row, IMAGE_CHEVRON, C_TXT)
			.set({ x: GROUP_W - ROW_PAD - CHEVRON,
			       y: int((h - CHEVRON) / 2) });

		return CHEVRON;
	}

	if (kind == 'eye') {
		let hit = lv.obj(row);

		hit.set({ x: GROUP_W - ROW_PAD - EYE - ROW_GAP,
			  y: 0, w: EYE + ROW_PAD + ROW_GAP, h });
		hit.style({ bg_opa: lv.OPA_TRANSP, border_width: 0, pad_all: 0,
			    radius: 0 });
		hit.scrollable(false);
		hit.clickable(opts.on_reveal != null);

		let eye = icon_new(hit, opts.revealed ? IMAGE_EYE_OFF
						      : IMAGE_EYE, C_ACTION);

		eye.set({ x: ROW_GAP, y: int((h - EYE) / 2) });
		entry.eye = eye;

		if (opts.on_reveal)
			hit.on(lv.EVENT_CLICKED, opts.on_reveal);

		return EYE;
	}

	if (kind == 'switch') {
		entry.toggle = switch_new(row, GROUP_W - ROW_PAD - SWITCH_W,
					  int((h - SWITCH_H) / 2), opts.on,
					  opts.on_toggle);

		return SWITCH_W;
	}

	return 0;
}

function row_text_new(row, font, colour, text, x, y, w, h) {
	let entry = text_new(row, font, colour, text);

	entry.obj.set({ x, y, w, h });
	/* DOTS needs the height as well as the width: LVGL only ellipsises where
	   the text overflows vertically, and an auto height wraps instead. */
	entry.obj.long_mode(lv.LABEL_LONG_DOTS);

	return entry;
}

/**
 * row_new - the list row
 * @group: the group to build it in
 * @y: top edge within the group
 * @opts: h and large for the size and type tier; dot, icon, label, secondary,
 *        secondary_colour, value, value_font, value_colour and signal for the
 *        content; accessory of chevron, eye or switch; on_tap, on_toggle,
 *        on_reveal and revealed for the handlers
 *
 * Return: an entry carrying obj, label, secondary, value, and whichever of
 *         signal, toggle and eye the row was given, so a page changes one in
 *         place rather than rebuilding the row from its own handler.
 */
export function row_new(group, y, opts) {
	let h = opts.h ?? ROW_H;
	let tier = opts.large ? TIER_LARGE : TIER_SMALL;
	let row = lv.obj(group);

	row.set({ x: 0, y, w: GROUP_W, h });
	row.style({ bg_opa: lv.OPA_TRANSP, border_width: 0, pad_all: 0,
		    radius: 0 });
	row.style({ bg_color: C_RAISED, bg_opa: lv.OPA_COVER },
		  lv.PART_MAIN | lv.STATE_PRESSED);
	row.scrollable(false);
	row.clickable(opts.on_tap != null);

	let left = ROW_PAD;

	if (opts.dot != null) {
		dot_new(row, left, int((h - DOT_R) / 2), opts.dot);
		left += DOT_R + ROW_GAP;
	}

	if (opts.icon != null) {
		icon_new(row, opts.icon, C_TXT_DIM)
			.set({ x: left, y: int((h - ICON_H) / 2) });
		left += ICON_SLOT + ROW_GAP;
	}

	let entry = { obj: row };
	let used = row_accessory(row, entry, opts.accessory, opts, h);
	let right = GROUP_W - ROW_PAD - (used ? used + 5 : 0);

	if (opts.signal != null) {
		right -= SIG_W_ALL + ROW_GAP;

		entry.signal = signal_new(row, right + ROW_GAP,
					  int((h - SIG_BARS * SIG_STEP) / 2),
					  opts.signal);
	}

	let avail = right - left;

	if (opts.secondary != null) {
		let block = tier.label_h + LINE_GAP + tier.second_h;
		let top = int((h - block) / 2);

		entry.label = row_text_new(row, tier.label, C_TXT, opts.label,
					   left, top, avail, tier.label_h);
		entry.secondary = row_text_new(row, tier.second,
					       opts.secondary_colour ?? C_TXT_DIM,
					       opts.secondary, left,
					       top + tier.label_h + LINE_GAP,
					       avail, tier.second_h);
	}
	else {
		entry.label = row_text_new(row, tier.label, C_TXT, opts.label,
					   left, int((h - tier.label_h) / 2),
					   avail, tier.label_h);
	}

	if (opts.value != null) {
		let font = opts.value_font ?? tier.label;
		let font_h = opts.value_font ? LINE_UNIT : tier.label_h;

		entry.value = text_new(row, font, opts.value_colour ?? C_TXT_DIM,
				       opts.value);
		entry.value.obj.set({ x: left, y: int((h - font_h) / 2),
				      w: right - left });
		entry.value.obj.style({ text_align: lv.TEXT_ALIGN_RIGHT });
	}

	if (opts.on_tap) {
		let act = opts.activity ?? activity;

		row.on(lv.EVENT_PRESSED, function() {
			act?.();
		});
		row.on(lv.EVENT_CLICKED, opts.on_tap);
	}

	return entry;
};

/**
 * rows_height - the height a group needs
 * @count: how many rows
 * @h: the row height, or null for the sub page default
 *
 * Return: the rows plus a hairline between each.
 */
export function rows_height(count, h) {
	return count * (h ?? ROW_H) + (count - 1) * SEP_H;
};

/**
 * row_stacked_new - a caption above its value, for a value too wide to share
 * @group: the group to build it in
 * @y: top edge within the group
 * @caption: the field name
 * @value: the value, newline separated for several under one caption
 * @h: the row height, or null for the sub page default
 *
 * The face is chosen by measuring the longest line, never the joined string.
 *
 * Return: the row object.
 */
export function row_stacked_new(group, y, caption, value, h) {
	let height = h ?? ROW_H;
	let row = lv.obj(group);

	row.set({ x: 0, y, w: GROUP_W, h: height });
	row.style({ bg_opa: lv.OPA_TRANSP, border_width: 0, pad_all: 0,
		    radius: 0 });
	row.scrollable(false);
	row.clickable(false);

	let avail = GROUP_W - 2 * ROW_PAD;
	let lines = split(value, '\n');
	let widest = 0;

	for (let line in lines) {
		let w = lv.text_width(FONT_TNUM_12, line);

		if (w > widest)
			widest = w;
	}

	let fits = widest <= avail;
	let font = fits ? FONT_TNUM_12 : FONT_TNUM_10;
	let step = fits ? LINE_ADDR : LINE_ADDR_SM;
	let top = int((height - (LINE_CAPTION + LINE_GAP +
				 length(lines) * step)) / 2);

	label_new(row, FONT_REG_11, C_TXT_DIM, caption)
		.set({ x: ROW_PAD, y: top });
	label_new(row, font, C_TXT, value)
		.set({ x: ROW_PAD, y: top + LINE_CAPTION + LINE_GAP });

	return row;
};

/**
 * row_stacked_height - the height a stacked row needs
 * @value: the value it will carry
 * @h: the row height, or null for the sub page default
 *
 * Return: the height, at the larger of the two address steps.
 */
export function row_stacked_height(value, h) {
	return (h ?? ROW_H) + (length(split(value, '\n')) - 1) * LINE_ADDR;
};

const SCRIM_OPA		= 196;	/* 77 per cent */
const DIALOG_OPA	= 247;

const DIALOG_X		= 34;
const DIALOG_W		= CARD_W - 2 * DIALOG_X;
const DIALOG_RADIUS	= 13;
const DIALOG_PAD	= 15;
const DIALOG_BOTTOM	= 13;
const DIALOG_GAP	= 5;
const LINE_BODY		= 19;
const BUTTON_PAD	= 10;
const BUTTON_H		= BUTTON_PAD + LINE_BODY + BUTTON_PAD;

/**
 * dialog_new - a question over a scrim
 * @parent: the page tile
 * @opts: title and body; confirm, cancel, on_confirm and on_cancel for the
 *        usual two buttons, or choices of text, color and on for another
 *        arrangement; align for a statement that should not be centred;
 *        activity, for a page that builds no list
 *
 * The box height follows the body, and the whole is centred on the glass.
 *
 * Return: a handle carrying obj and close().
 */
export function dialog_new(parent, opts) {
	let scrim = lv.obj(parent);

	/* Also taken here: the one page that opens a dialog builds no list. */
	activity = opts.activity ?? activity;

	scrim.set({ x: 0, y: 0, w: CARD_W, h: H });
	scrim.style({ bg_color: C_SCREEN, bg_opa: SCRIM_OPA, border_width: 0,
		      pad_all: 0, radius: 0 });
	scrim.clickable(true);
	scrim.scrollable(false);

	scrim.on(lv.EVENT_PRESSED, function() {
		activity?.();
	});

	let avail = DIALOG_W - 2 * DIALOG_PAD;
	let lines = 0;

	for (let para in split(opts.body, '\n')) {
		let wide = int((lv.text_width(FONT_REG_11, para) + avail - 1) /
			       avail);

		lines += wide > 0 ? wide : 1;
	}

	if (lines < 1)
		lines = 1;

	let head = DIALOG_PAD + LINE_BODY + DIALOG_GAP + lines * LINE_CAPTION +
		   DIALOG_BOTTOM;
	let box = lv.obj(scrim);

	let tall = head + SEP_H + BUTTON_H;

	box.set({ x: DIALOG_X, y: int((H - tall) / 2), w: DIALOG_W, h: tall });
	box.style({ bg_color: C_RAISED, bg_opa: DIALOG_OPA,
		    radius: DIALOG_RADIUS, border_width: 0, pad_all: 0 });
	box.clickable(false);
	box.scrollable(false);

	let align = opts.align ?? lv.TEXT_ALIGN_CENTER;
	let indent = align == lv.TEXT_ALIGN_CENTER ? 0 : DIALOG_PAD;
	let title = label_new(box, FONT_SEMI_15, C_TXT, opts.title);

	title.set({ x: indent, y: DIALOG_PAD, w: DIALOG_W - 2 * indent });
	title.style({ text_align: align });

	let body = label_new(box, FONT_REG_11, C_TXT_DIM, opts.body);

	body.set({ x: DIALOG_PAD, y: DIALOG_PAD + LINE_BODY + DIALOG_GAP,
		   w: avail });
	body.style({ text_align: align });

	let rule = box_new(box, C_DOWN, 0);

	rule.set({ x: 0, y: head, w: DIALOG_W, h: SEP_H });

	let dialog = { obj: scrim };

	dialog.close = function() {
		scrim.delete();
	};

	let choices = opts.choices ?? [
		{ text: opts.cancel ?? 'Cancel', color: C_ACTION, on: opts.on_cancel },
		{ text: opts.confirm, color: C_ALERT, on: opts.on_confirm }
	];
	let count = length(choices);
	let width = int(DIALOG_W / count);

	if (count > 1) {
		let split = box_new(box, C_DOWN, 0);

		split.set({ x: width, y: head + SEP_H, w: SEP_H, h: BUTTON_H });
	}

	for (let i = 0; i < count; i++) {
		let choice = choices[i];
		let button = lv.obj(box);

		button.set({ x: i * width, y: head + SEP_H, w: width,
			     h: BUTTON_H });
		button.style({ bg_opa: lv.OPA_TRANSP, border_width: 0,
			       pad_all: 0, radius: 0 });
		button.clickable(true);
		button.scrollable(false);

		let text = label_new(button, FONT_REG_15,
				     choice.color ?? C_ACTION, choice.text);

		text.set({ x: 0, y: BUTTON_PAD, w: width });
		text.style({ text_align: lv.TEXT_ALIGN_CENTER });

		button.on(lv.EVENT_CLICKED, choice.on);
	}

	return dialog;
};

/**
 * list_new - the shape every list page takes
 * @parent: the page tile
 * @opts: title, indented and count for the header; height, for a page that is
 *        not full length; activity, which every page owes
 *
 * The header does not scroll. The caller owes nothing but the groups.
 *
 * Return: the area to build the groups on.
 */
export function list_new(parent, opts) {
	let height = opts.height ?? LIST_H;

	activity = opts.activity;

	header_new(parent, opts.title, opts.indented, opts.count);

	let area = lv.obj(parent);

	area.set({ x: 0, y: HEAD_H, w: CARD_W, h: height - HEAD_H });
	area.style({ bg_opa: lv.OPA_TRANSP, border_width: 0, pad_all: 0,
		     radius: 0 });
	area.clickable(false);
	area.scrollable(false);

	return area;
};
