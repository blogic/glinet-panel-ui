'use strict';

/*
 * The limit on wrong PINs. Pure arithmetic over a clock the caller passes in,
 * so it can be checked without a display (test/pin-guard.uc).
 *
 * The first few failures are free. The next one locks the keypad, and every
 * failure after a lock doubles the wait. A quiet hour forgets the count, so a
 * typo weeks later costs nothing. The state lives in RAM: a restart clears it,
 * and a restart takes longer than the first lock.
 */

export const GUARD_FREE		= 5;	/* the failure that first locks */
export const GUARD_FIRST	= 30;	/* seconds */
export const GUARD_MAX		= 900;
export const GUARD_FORGET	= 3600;

export function guard_new() {
	return { fails: 0, last: null, until: 0 };
};

/**
 * guard_fail - count one wrong PIN
 * @g: the guard
 * @now: the clock, in seconds
 */
export function guard_fail(g, now) {
	if (g.last != null && now - g.last >= GUARD_FORGET)
		g.fails = 0;

	g.fails++;
	g.last = now;

	if (g.fails < GUARD_FREE)
		return;

	let wait = GUARD_FIRST;

	for (let i = GUARD_FREE; i < g.fails && wait < GUARD_MAX; i++)
		wait *= 2;

	g.until = now + (wait > GUARD_MAX ? GUARD_MAX : wait);
};

export function guard_ok(g) {
	g.fails = 0;
	g.last = null;
	g.until = 0;
};

/**
 * guard_wait - how long the keypad stays locked
 * @g: the guard
 * @now: the clock, in seconds
 *
 * Return: the seconds left, 0 when it takes digits.
 */
export function guard_wait(g, now) {
	return g.until > now ? g.until - now : 0;
};

/* Minutes round up, so the prompt never promises less than the wait. */
export function guard_text(wait) {
	if (wait < 60)
		return sprintf('Try again in %d s', wait);

	return sprintf('Try again in %d min', int((wait + 59) / 60));
};
