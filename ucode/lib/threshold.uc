'use strict';

import { C_OK, C_WARN, C_ALERT } from './theme.uc';

/*
 * One ladder for CPU, memory, flash and temperature. The two boundaries
 * coincide by luck rather than by design, and one pair is still worth more than
 * four tuned pairs.
 */
export const WARN = 60;
export const CRIT = 85;

/**
 * threshold_colour - the band a reading falls in
 * @value: a percentage, or a temperature in C
 *
 * Only for a statistic where a high reading is bad. A value with no health
 * meaning takes no threshold colour, and good needs no colour at all.
 */
export function threshold_colour(value) {
	if (value >= CRIT)
		return C_ALERT;

	if (value >= WARN)
		return C_WARN;

	return C_OK;
};
