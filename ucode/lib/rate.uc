'use strict';

/*
 * The one byte rate ladder. The traffic page and the idle screen each carried a
 * copy, differing only in whether they answered an array or an object.
 *
 * Safe to import from a page, like lib/weather.uc, only because it holds no
 * state. The loadfile() rule still stands for anything that does.
 */

const KB = 1000;
const MB = 1000000;
const GB = 1000000000;

/* Never a bare byte count: below this a quiet link reads as nothing at all. */
const KB_MIN = 0.1;

/* Three significant digits at most, and truncated rather than rounded, so a
   reading never overstates the link. */
function number_fmt(value) {
	if (value >= 100)
		return sprintf('%d', int(value));

	return sprintf('%.1f', int(value * 10) / 10.0);
}

/**
 * rate_fmt - a byte rate as a value and a unit
 * @bytes: the rate in bytes per second
 *
 * Bytes, never bits: the kernel counters are bytes and so is the readout. The
 * rate is held in B/s rather than kB/s, because in kB/s everything under a
 * kilobyte a second floors to zero, which is most of what a quiet link does.
 *
 * No per second suffix. The panel shows rates throughout, and the suffix costs
 * width the value needs.
 *
 * Return: value and unit, of KB, MB or GB.
 */
export function rate_fmt(bytes) {
	if (bytes >= GB)
		return { value: number_fmt(bytes / (GB * 1.0)), unit: 'GB' };

	if (bytes >= MB)
		return { value: number_fmt(bytes / (MB * 1.0)), unit: 'MB' };

	let kb = bytes / (KB * 1.0);

	return { value: number_fmt(kb < KB_MIN ? KB_MIN : kb), unit: 'KB' };
};
