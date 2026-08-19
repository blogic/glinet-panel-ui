'use strict';

import * as lv from 'lv';

/* The loader below needs LVGL up, and this runs before panel.uc reaches its own
   lv.init(). Idempotent, so that later call is a no-op. */
lv.init();

const ICON_DIR	= '/usr/share/glinet-panel-ui/icons';

function mark(name) {
	return lv.image_load(sprintf('%s/%s.png', ICON_DIR, name), true);
}

export const IMAGE_COMPUTER	= mark('icon_computer');
export const IMAGE_PHONE	= mark('icon_phone');
export const IMAGE_TV		= mark('icon_tv');
export const IMAGE_CONSOLE	= mark('icon_console');
export const IMAGE_PRINTER	= mark('icon_printer');
export const IMAGE_DEVICE	= mark('icon_device');
export const IMAGE_JACK_LG	= mark('icon_jack_lg');
export const IMAGE_JACK_SM	= mark('icon_jack_sm');
export const IMAGE_CAGE_LG	= mark('icon_cage_lg');
export const IMAGE_CAGE_SM	= mark('icon_cage_sm');

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
