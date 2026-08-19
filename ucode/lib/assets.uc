'use strict';

import * as lv from 'lv';

/* Both loaders below need LVGL up, and this runs before panel.uc reaches its
   own lv.init(). Idempotent, so that later call is a no-op. */
lv.init();

const FONT_DIR	= '/usr/share/glinet-panel-ui/fonts';
const ICON_DIR	= '/usr/share/glinet-panel-ui/icons';

function face(name) {
	return lv.font_load(sprintf('%s/%s.bin', FONT_DIR, name));
}

function mark(name) {
	return lv.image_load(sprintf('%s/%s.png', ICON_DIR, name), true);
}

/*
 * A face is named for what it is, because a name for what it draws goes stale:
 * the 26 was called MERIDIEM and never drew one, and the 27 was called RATE
 * after the traffic page had moved off it.
 *
 * Two faces at one size are a weight apart on purpose. Where sizes are close
 * the weight carries the hierarchy, because at 10 px a single pixel of size is
 * invisible on this glass.
 *
 * TNUM is a cut, not a modifier: its digits, full stop, comma and colon are
 * remapped onto tabular variants so an address sits on a fixed grid, and it is
 * not interchangeable with the regular cut of the same size.
 *
 * LIGHT and THIN carry digits and a separator only. That restriction, not the
 * size, is what makes them cheap: the 112 px clock costs less than the 26 px
 * regular face beside it.
 */
export const FONT_TNUM_10	= face('inter_regular_10_tnum');
export const FONT_SEMI_10	= face('inter_semibold_10');
export const FONT_REG_11	= face('inter_regular_11');
export const FONT_TNUM_12	= face('inter_regular_12_tnum');
export const FONT_REG_13	= face('inter_regular_13');
export const FONT_REG_15	= face('inter_regular_15');
export const FONT_SEMI_15	= face('inter_semibold_15');
export const FONT_REG_20	= face('inter_regular_20');
export const FONT_SEMI_21	= face('inter_semibold_21');
export const FONT_REG_26	= face('inter_regular_26');
export const FONT_LIGHT_27	= face('inter_light_27');
export const FONT_LIGHT_45	= face('inter_light_45');
export const FONT_THIN_112	= face('inter_thin_112');

export const IMAGE_CHEVRON	= mark('icon_chevron');
export const IMAGE_BACK		= mark('icon_back');
export const IMAGE_EYE		= mark('icon_eye');
export const IMAGE_EYE_OFF	= mark('icon_eye_off');
export const IMAGE_BACKSPACE	= mark('icon_backspace');
export const IMAGE_COMPUTER	= mark('icon_computer');
export const IMAGE_PHONE	= mark('icon_phone');
export const IMAGE_TV		= mark('icon_tv');
export const IMAGE_CONSOLE	= mark('icon_console');
export const IMAGE_PRINTER	= mark('icon_printer');
export const IMAGE_LOCK		= mark('icon_lock');
export const IMAGE_SUN		= mark('icon_sun');
export const IMAGE_DEVICE	= mark('icon_device');
export const IMAGE_JACK_LG	= mark('icon_jack_lg');
export const IMAGE_JACK_SM	= mark('icon_jack_sm');
export const IMAGE_CAGE_LG	= mark('icon_cage_lg');
export const IMAGE_CAGE_SM	= mark('icon_cage_sm');
export const IMAGE_INFO		= mark('icon_info');

export const IMAGE_WX_CLEAR_LG	= mark('icon_wx_clear_lg');
export const IMAGE_WX_PARTLY_LG	= mark('icon_wx_partly_lg');
export const IMAGE_WX_CLOUD_LG	= mark('icon_wx_cloud_lg');
export const IMAGE_WX_RAIN_LG	= mark('icon_wx_rain_lg');
export const IMAGE_WX_SNOW_LG	= mark('icon_wx_snow_lg');
export const IMAGE_WX_STORM_LG	= mark('icon_wx_storm_lg');
export const IMAGE_WX_CLEAR_SM	= mark('icon_wx_clear_sm');
export const IMAGE_WX_PARTLY_SM	= mark('icon_wx_partly_sm');
export const IMAGE_WX_CLOUD_SM	= mark('icon_wx_cloud_sm');
export const IMAGE_WX_RAIN_SM	= mark('icon_wx_rain_sm');
export const IMAGE_WX_SNOW_SM	= mark('icon_wx_snow_sm');
export const IMAGE_WX_STORM_SM	= mark('icon_wx_storm_sm');
export const IMAGE_WX_CLEAR_NIGHT = mark('icon_wx_clear_night');
export const IMAGE_WX_PARTLY_NIGHT = mark('icon_wx_partly_night');

/* RGB565, not coverage: the logo is the one mark that carries its own colour. */
export const IMAGE_LOGO = lv.image_load(ICON_DIR + '/openwrt_logo.png');
