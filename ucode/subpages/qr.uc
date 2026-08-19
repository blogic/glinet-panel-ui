'use strict';

import * as lv from 'lv';
import { C_TXT_DIM, W, H } from '../lib/theme.uc';
import { label_new } from '../lib/widget.uc';
import { flow_new } from '../lib/layout.uc';
import { qrplate_new, CAP_GAP } from '../lib/component/qrplate.uc';
import { qr_payload } from '../lib/qr.uc';
import { FONT_REG_11 } from '../lib/assets.uc';

let state;
let plate, caption;
let name;

function net_of() {
	for (let entry in state.networks)
		if (entry.ssid == name)
			return entry;

	return null;
}

function page_update(source) {
	let net = net_of();
	let payload = net?.up ? qr_payload(net) : null;

	if (!plate.set(payload))
		return;

	if (!payload) {
		caption.text(net ? 'Network is off' : 'Network is gone');

		return;
	}

	caption.text(sprintf('%s · %s', net.ssid, net.security));
}

function page_build(parent, ctx) {
	state = ctx.state;
	name = ctx.params?.ssid;

	let column = flow_new(parent, { dir: 'column', main: 'centre',
					cross: 'centre', gap: CAP_GAP,
					w: W, h: H });

	plate = qrplate_new(column);

	caption = label_new(column, FONT_REG_11, C_TXT_DIM, '');
	caption.set({ w: W });
	caption.style({ text_align: lv.TEXT_ALIGN_CENTER });

	page_update(null);
}

return {
	needs: [ 'wireless' ],
	build: page_build,
	update: page_update
};
