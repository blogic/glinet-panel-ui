'use strict';

import * as lv from 'lv';
import { IMAGE_WX_CLEAR_LG, IMAGE_WX_CLEAR_NIGHT, IMAGE_WX_CLEAR_SM,
	 IMAGE_WX_CLOUD_LG, IMAGE_WX_CLOUD_SM, IMAGE_WX_PARTLY_LG,
	 IMAGE_WX_PARTLY_NIGHT, IMAGE_WX_PARTLY_SM, IMAGE_WX_RAIN_LG,
	 IMAGE_WX_RAIN_SM, IMAGE_WX_SNOW_LG, IMAGE_WX_SNOW_SM,
	 IMAGE_WX_STORM_LG, IMAGE_WX_STORM_SM } from './assets.uc';

const SKY_LG = {
	clear:  IMAGE_WX_CLEAR_LG,
	partly: IMAGE_WX_PARTLY_LG,
	cloud:  IMAGE_WX_CLOUD_LG,
	rain:   IMAGE_WX_RAIN_LG,
	snow:   IMAGE_WX_SNOW_LG,
	storm:  IMAGE_WX_STORM_LG
};

const SKY_NIGHT = {
	clear:  IMAGE_WX_CLEAR_NIGHT,
	partly: IMAGE_WX_PARTLY_NIGHT
};

const SKY_SM = {
	clear:  IMAGE_WX_CLEAR_SM,
	partly: IMAGE_WX_PARTLY_SM,
	cloud:  IMAGE_WX_CLOUD_SM,
	rain:   IMAGE_WX_RAIN_SM,
	snow:   IMAGE_WX_SNOW_SM,
	storm:  IMAGE_WX_STORM_SM
};

export const NO_READING = '—';

/*
 * U+2212, not the hyphen. The 45 px face is cut with the true minus, because a
 * hyphen sits too high and too short against digits that size, so a reading
 * printed with %d loses its sign to a missing glyph below zero. Every other
 * face carries both, so one spelling serves them all.
 */
const MINUS = 0x2212;

/**
 * sky_image - the large sky glyph for the current conditions
 * @glyph: a glyph name from state.weather
 * @day: false to take the night variant where one exists
 *
 * Return: an image handle, falling back to cloud for an unknown name.
 */
export function sky_image(glyph, day) {
	if (!day && SKY_NIGHT[glyph] != null)
		return SKY_NIGHT[glyph];

	return SKY_LG[glyph] ?? SKY_LG.cloud;
};

/**
 * sky_small - the forecast column sky glyph
 * @glyph: a glyph name from state.weather
 *
 * Return: an image handle, falling back to cloud for an unknown name.
 */
export function sky_small(glyph) {
	return SKY_SM[glyph] ?? SKY_SM.cloud;
};

/**
 * degrees - format a temperature for a restricted face
 * @value: the reading, or null
 *
 * Return: the digits with a true minus below zero, or NO_READING.
 */
export function degrees(value) {
	if (value == null)
		return NO_READING;

	if (value < 0)
		return sprintf('%s%d', uchr(MINUS), -value);

	return sprintf('%d', value);
};

/**
 * degrees_unit - degrees() with the degree sign appended
 * @value: the reading, or null
 *
 * Return: the reading and its unit, or NO_READING on its own.
 */
export function degrees_unit(value) {
	return value == null ? NO_READING : degrees(value) + '°';
};
