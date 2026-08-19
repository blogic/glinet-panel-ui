'use strict';

import * as lv from 'lv';
import * as ubus from 'ubus';
import { FONT_REG_15 } from '../lib/assets.uc';
import { C_SURFACE, C_ALERT, C_TXT, W, GROUP_X, GROUP_W, GROUP_RADIUS,
	 ROW_H } from '../lib/theme.uc';
import { label_new, header_new, dialog_new,
	 card_opacity } from '../lib/widget.uc';
import { body_new, SIZE_CONTENT } from '../lib/layout.uc';

const BODY_X	= 12;
const BODY_W	= W - 2 * BODY_X;

const BODY = 'Restarts the router. All clients will drop and need to ' +
	     'reconnect. The device is offline for 1 to 2 minutes.';

let activity, defer;
let parent_obj, dialog;

function reboot_run() {
	try {
		ubus.call({ object: 'system', method: 'reboot', data: {} });
	}
	catch (e) {
		warn(sprintf('panel: reboot failed: %s\n', e));
	}
}

function dialog_close() {
	activity();

	if (!dialog)
		return;

	/* A button must not delete the dialog it is part of from its own
	   handler: the indev still holds the pressed object. */
	let doomed = dialog;

	dialog = null;

	defer(function() {
		doomed.close();
	});
}

function dialog_open() {
	activity();

	if (dialog)
		return;

	dialog = dialog_new(parent_obj, {
		title: 'Reboot now?',
		body: 'All clients will lose connectivity.',
		confirm: 'Reboot',
		activity,
		on_cancel: dialog_close,
		on_confirm: function() {
			dialog_close();
			reboot_run();
		}
	});
}

function page_build(parent, ctx) {
	activity = ctx.activity;
	defer = ctx.defer;
	parent_obj = parent;

	header_new(parent, 'Reboot', false, null);

	let body_area = body_new(parent, { dir: 'column', main: 'evenly',
					   cross: 'centre' });

	let body = label_new(body_area, FONT_REG_15, C_TXT, BODY);

	body.set({ w: BODY_W, h: SIZE_CONTENT });
	body.style({ text_align: lv.TEXT_ALIGN_CENTER, pad_all: 0,
		     border_width: 0 });

	/* Card fill and card opacity, or it is the one solid surface left on a
	   translucent panel. */
	let button = lv.obj(body_area);

	button.set({ w: GROUP_W, h: ROW_H });
	button.style({ bg_color: C_SURFACE, bg_opa: card_opacity(),
		       radius: GROUP_RADIUS, border_width: 0, pad_all: 0 });
	button.clickable(true);
	button.scrollable(false);
	button.on(lv.EVENT_CLICKED, dialog_open);

	let text = label_new(button, FONT_REG_15, C_ALERT, 'Reboot');

	text.set({ align: lv.ALIGN_CENTER });
}

function page_leave() {
	dialog_close();
}

return {
	needs: [],
	build: page_build,
	leave: page_leave
};
