'use strict';

import * as lv from 'lv';
import { FONT_SEMI_15, FONT_REG_15 } from '../assets.uc';
import { C_RULE, C_TXT } from '../theme.uc';
import { threshold_colour } from '../threshold.uc';
import { flow_new } from '../layout.uc';
import { label_new, text_new, text_set } from '../widget.uc';

const ROTATION	= 135;
const SPAN	= 270;
const WIDTH	= 5;
const ANIM_MS	= 300;

const SWEEP_LOW	 = 0;
const SWEEP_HIGH = 100;

const SIZE	= 72;
const GAP	= 10;
const EDGE	= 20;

function sweep_of(value, low, high) {
	let sweep = int((value - low) * 100 / (high - low));

	if (sweep < SWEEP_LOW)
		return SWEEP_LOW;

	if (sweep > SWEEP_HIGH)
		return SWEEP_HIGH;

	return sweep;
}

function ring_new(parent) {
	let arc = lv.arc(parent);

	arc.set({ w: SIZE, h: SIZE });
	arc.rotation(ROTATION);
	arc.bg_angles(0, SPAN);
	arc.range(SWEEP_LOW, SWEEP_HIGH);
	arc.value(SWEEP_LOW);
	arc.remove_style(lv.PART_KNOB);
	arc.clickable(false);
	arc.scrollable(false);
	/* The unfilled track is C_RULE: a gauge's empty part and the line between
	   two rows are one idea and take one colour. */
	arc.style({ arc_width: WIDTH, arc_rounded: true, arc_color: C_RULE,
		    bg_opa: lv.OPA_TRANSP, border_width: 0, pad_all: 0 });
	arc.style({ arc_width: WIDTH, arc_rounded: true, arc_color: C_RULE },
		  lv.PART_INDICATOR);

	return arc;
}

/**
 * gauge_new - an arc with its reading inside it and a caption beside it
 * @parent: the cell it fills
 * @opts: caption; side, left or right, for the edge the ring goes to; unit, the
 *	  one character the reading ends in; low and high, the range mapped onto
 *	  the travel, 0 and 100 by default
 *
 * Sweep and colour are separate inputs: a range mapped onto the travel still
 * takes its colour from the raw reading. The arc is coloured and the number is
 * not.
 *
 * Return: a handle carrying obj and set(value). set(null) hides the gauge,
 * because zero clamps to an empty green ring and claims the chip is cold.
 */
export function gauge_new(parent, opts) {
	let right = opts.side == 'right';
	let low = opts.low ?? SWEEP_LOW;
	let high = opts.high ?? SWEEP_HIGH;
	let unit = opts.unit ?? '';
	let root = flow_new(parent, { dir: 'row', gap: GAP, cross: 'centre',
				      main: right ? 'end' : 'start' });
	let arc;

	root.style(right ? { pad_right: EDGE } : { pad_left: EDGE });

	if (!right)
		arc = ring_new(root);

	let caption = label_new(root, FONT_REG_15, C_TXT, opts.caption);

	caption.style({ pad_all: 0, border_width: 0 });

	if (right)
		arc = ring_new(root);

	let reading = text_new(arc, FONT_SEMI_15, C_TXT, '');

	reading.obj.set({ align: lv.ALIGN_CENTER });

	let gauge = { obj: root };
	let sweep_shown = -1;
	let colour_shown;

	gauge.set = function(value) {
		if (value == null) {
			root.hidden(true);

			return;
		}

		root.hidden(false);
		text_set(reading, sprintf('%d%s', int(value), unit));

		let colour = threshold_colour(value);

		if (colour_shown != colour) {
			colour_shown = colour;
			arc.style({ arc_color: colour }, lv.PART_INDICATOR);
		}

		let sweep = sweep_of(value, low, high);

		if (sweep_shown == sweep)
			return;

		sweep_shown = sweep;
		arc.anim(sweep, ANIM_MS);
	};

	return gauge;
};
