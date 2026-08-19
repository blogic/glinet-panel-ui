'use strict';

import * as lv from 'lv';
import { C_SCREEN, C_TXT } from '../theme.uc';
import { box_new } from '../widget.uc';

/* The plate is the quiet zone a reader needs, which the panel's background
   cannot provide: it is neither white nor even. */
const QR_SIZE	= 112;
const QR_PAD	= 10;
const PLATE_R	= 6;

export const PLATE = QR_SIZE + 2 * QR_PAD;

/* Between the plate and the line naming what the code joins. */
export const CAP_GAP = 10;

/**
 * qrplate_new - a QR code on its plate
 * @parent: what to build it on, which places it
 *
 * Return: a handle carrying obj, the plate, and set(payload). set(null) hides
 * it: a code that cannot be used is worse than an absent one.
 */
export function qrplate_new(parent) {
	let plate = box_new(parent, C_TXT, PLATE_R);

	plate.set({ w: PLATE, h: PLATE });

	let code = lv.qrcode(plate);

	/* Size and colours configure the draw buffer, so they precede any
	   payload: qr_update() allocates and renders. */
	code.qr_size(QR_SIZE);
	code.qr_colors(C_SCREEN, C_TXT);
	code.set({ x: QR_PAD, y: QR_PAD });
	code.clickable(false);

	let handle = { obj: plate };
	let shown = false;

	handle.set = function(payload) {
		if (shown == payload)
			return false;

		shown = payload;
		plate.hidden(!payload);

		if (payload)
			code.qr_update(payload);

		return true;
	};

	return handle;
};
