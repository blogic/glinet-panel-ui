'use strict';

/*
 * Where things go, and nothing about what they look like.
 *
 * Two halves. The solvers are integer arithmetic and build nothing, so they can
 * be checked against the constants they replace. The containers build one
 * transparent object each and hand the placing to LVGL.
 *
 * Separate from widget.uc because widget.uc is the biggest consumer of this:
 * a module cannot import itself.
 */

import * as lv from 'lv';
import { W, BODY_Y, BODY_H } from './theme.uc';

/*
 * A track size for grid_new(). A number is pixels, 'content' is as wide as
 * whatever the cell holds, and '<n>fr' is a share of what the fixed tracks
 * leave over.
 */
function track_size(size) {
	if (type(size) != 'string')
		return size;

	if (size == 'content')
		return lv.GRID_CONTENT;

	let fr = match(size, /^([0-9]+)fr$/);

	if (!fr)
		die(sprintf('layout: %s is not a track size', size));

	return lv.grid_fr(+fr[1]);
}

function track_array(sizes) {
	let out = [];

	for (let size in sizes)
		push(out, track_size(size));

	return out;
}

/**
 * SIZE_CONTENT - as large as the thing inside it
 *
 * Safe at the end of a flow, where nothing is placed after it. Anywhere else a
 * string that grows moves its neighbours, which is the bug the idle rate line
 * was built to avoid.
 */
export const SIZE_CONTENT = lv.SIZE_CONTENT;

/**
 * pct - a size as a share of the parent's content area
 */
export function pct(value) {
	return lv.pct(value);
};

/**
 * centre - where a child of a known length starts, to sit in the middle of one
 * @space: the length available
 * @size: the child's length
 *
 * Only for a child a layout cannot place. A label centres by taking the column
 * width and text_align CENTER, and a flow centres on its cross axis, so neither
 * needs this.
 */
export function centre(space, size) {
	return int((space - size) / 2);
};

/**
 * span - the length @count children of one size occupy, gaps included
 */
export function span(size, count, gap) {
	return count * size + (count - 1) * (gap ?? 0);
};

/**
 * cells_at - the offset of each of @count children laid on one pitch
 *
 * Return: an array of @count offsets, so a loop indexes them rather than
 * working the pitch out again on every pass.
 */
export function cells_at(start, size, count, gap) {
	let step = size + (gap ?? 0);
	let out = [];

	for (let i = 0; i < count; i++)
		push(out, start + i * step);

	return out;
};

/**
 * divide - split a length into @count equal cells
 *
 * The remainder collects outside the block rather than inside it, so the cells
 * stay equal and the block stays centred. This was spelled four different ways
 * and they disagreed about the pixel that does not divide.
 *
 * Return: size, and at, an array of offsets.
 */
export function divide(space, count, gap) {
	let step = gap ?? 0;
	let size = int((space - (count - 1) * step) / count);

	return { size, at: cells_at(centre(space, span(size, count, step)),
				    size, count, step) };
};

/**
 * stack_at - the top of each item in a column of differing heights
 *
 * Return: an array one longer than @heights, so the last entry is where the
 * column ends and no caller keeps a running total.
 */
export function stack_at(start, heights, gap) {
	let step = gap ?? 0;
	let at = [];
	let top = start;

	for (let h in heights) {
		push(at, top);
		top += h + step;
	}

	push(at, length(heights) ? top - step : start);

	return at;
};

/**
 * chain_at - lengths placed outward from a fixed anchor
 * @edge: the anchor's near edge, which going left is its right edge
 * @sizes: the lengths that follow, nearest the anchor first
 * @gap: between each
 * @dir: 1 to march right, -1 to march left
 *
 * The idle rate line is built this way on purpose. Centring the string meant
 * every digit that changed width moved the whole line, so the dot is pinned to
 * the middle of the glass and everything else is placed outward from it. A flow
 * of content sized children would put that back: it promises that no reading
 * overlaps another, which is not the same as no reading moving another.
 *
 * Return: the near edge of each of @sizes, in the order given.
 */
export function chain_at(edge, sizes, gap, dir) {
	let step = gap ?? 0;
	let at = [];
	let cursor = edge;

	for (let size in sizes) {
		cursor += dir * step;

		if (dir < 0)
			cursor -= size;

		push(at, cursor);

		if (dir > 0)
			cursor += size;
	}

	return at;
};

/* Below the solvers, so a key called centre does not read as a call to one. */
const FLOW = {
	row:		lv.FLEX_FLOW_ROW,
	row_wrap:	lv.FLEX_FLOW_ROW_WRAP,
	column:		lv.FLEX_FLOW_COLUMN
};

const ALIGN = {
	start:		lv.FLEX_ALIGN_START,
	end:		lv.FLEX_ALIGN_END,
	centre:		lv.FLEX_ALIGN_CENTER,
	between:	lv.FLEX_ALIGN_SPACE_BETWEEN,
	around:		lv.FLEX_ALIGN_SPACE_AROUND,
	evenly:		lv.FLEX_ALIGN_SPACE_EVENLY
};

const CELL = {
	start:		lv.GRID_ALIGN_START,
	end:		lv.GRID_ALIGN_END,
	centre:		lv.GRID_ALIGN_CENTER,
	stretch:	lv.GRID_ALIGN_STRETCH
};

function region_new(parent, opts) {
	let o = opts ?? {};
	let box = lv.obj(parent);

	/*
	 * pad_all does not cover pad_row and pad_column, and the default theme
	 * sets both. Flex and grid read them as the gap, so a container that
	 * leaves them alone gets a 12 px gap it never asked for.
	 */
	box.style({ bg_opa: lv.OPA_TRANSP, border_width: 0, radius: 0,
		    pad_all: o.pad ?? 0, pad_row: 0, pad_column: 0 });
	box.clickable(false);
	box.scrollable(false);
	box.set({ x: o.x ?? 0, y: o.y ?? 0,
		  w: o.w ?? pct(100), h: o.h ?? pct(100) });

	return box;
}

/**
 * frame_new - a transparent rectangle with no layout, whose children place
 *	       themselves inside it
 *
 * The escape hatch, and where anything the design pins by hand belongs. A child
 * of a flow or a grid has x, y, align, align_to and translate ignored, all of
 * them and all at once, because lv_obj_refr_pos() returns as soon as it sees a
 * layout on the parent.
 */
export function frame_new(parent, opts) {
	return region_new(parent, opts);
};

/**
 * flow_set - give an object that already exists a flow
 * @obj: the container
 * @opts: as flow_new, without the geometry
 *
 * For a container built by something else, such as a scroll area, where adding
 * one to hold the flow would put an object between it and its children and
 * change what it measures as scrollable.
 *
 * Return: @obj.
 */
export function flow_set(obj, opts) {
	let o = opts ?? {};
	let box = obj;

	let dir = o.dir ?? 'column';
	let cross = o.cross ?? 'start';

	/*
	 * cross places an item inside its track, and the third argument places
	 * the track inside the container. A flow that does not wrap has one
	 * track as tall as its tallest item, so setting only the first leaves
	 * the whole track at the near edge and nothing appears to centre. For
	 * one track the two are the same question, so cross answers both.
	 */
	box.flex_flow(FLOW[dir]);
	box.flex_align(ALIGN[o.main ?? 'start'], ALIGN[cross],
		       ALIGN[o.track ?? (dir == 'row_wrap' ? 'start' : cross)]);

	/*
	 * Both, always, and never left to the theme. pad_all does not cover
	 * these two and the default theme sets both, so a container that does
	 * not name them gets a 12 px gap it never asked for. region_new()
	 * clears them, but this also runs on objects built elsewhere.
	 */
	let gap = o.gap ?? 0;
	let along = dir == 'row' || dir == 'row_wrap';

	box.style({ pad_column: along ? gap : 0,
		    pad_row: along ? (o.gap_cross ?? 0) : gap });

	return box;
};

/**
 * flow_new - a container that places its children in the order they were built
 * @opts: dir, one of row, row_wrap or column; main and cross, where the children
 *	  sit on each axis, start by default; gap; and the frame_new geometry
 *
 * A child keeps the size it was given. Only grow_set() lets the flow write it,
 * so a fixed cell stays a fixed cell.
 *
 * One child leaves the flow with flag('ignore_layout', true), or
 * flag('floating', true) to be left out of the size the flow measures too.
 */
export function flow_new(parent, opts) {
	return flow_set(region_new(parent, opts ?? {}), opts);
};

/**
 * grow_set - what share of the flow's spare length a child takes
 */
export function grow_set(child, weight) {
	(child.obj ?? child).flex_grow(weight ?? 1);

	return child;
};

/**
 * grid_new - a container of tracks
 * @opts: cols and rows, arrays of track sizes; gap_x and gap_y; and the
 *	  frame_new geometry
 */
export function grid_new(parent, opts) {
	let box = region_new(parent, opts);

	box.grid_dsc(track_array(opts.cols), track_array(opts.rows));
	box.style({ pad_column: opts.gap_x ?? 0, pad_row: opts.gap_y ?? 0 });

	return box;
};

/**
 * cell_set - put a child in a grid cell
 * @child: a widget, or a component handle carrying obj
 * @col: the column, counted from zero
 * @row: the row
 * @opts: span_x and span_y, 1 by default; align_x and align_y, stretch by
 *	  default, which is the one case where the grid writes the child's size
 *
 * Build a cell with the alignment it is going to keep. A cell that was
 * stretched keeps that size when it is re-aligned later, because lv_grid takes
 * the new size from the item's current coordinates.
 *
 * Return: @child, so a component can be placed as it is built.
 */
export function cell_set(child, col, row, opts) {
	let o = opts ?? {};

	(child.obj ?? child).grid_cell(col, row, {
		span_x: o.span_x ?? 1,
		span_y: o.span_y ?? 1,
		align_x: CELL[o.align_x ?? 'stretch'],
		align_y: CELL[o.align_y ?? 'stretch']
	});

	return child;
};

/**
 * body_new - the strip every page draws into, under the fixed header
 * @opts: as frame_new, flow_new or grid_new, whichever the options name
 */
export function body_new(parent, opts) {
	let o = { ...(opts ?? {}), x: 0, y: BODY_Y, w: W, h: BODY_H };

	if (o.cols)
		return grid_new(parent, o);

	if (o.dir)
		return flow_new(parent, o);

	return frame_new(parent, o);
};

/**
 * key_of - join what a rebuild depends on into one string
 */
export function key_of(items, fn) {
	let parts = [];

	for (let item in items)
		push(parts, fn(item));

	return join('\n', parts);
};

/**
 * keyed_new - a holder that rebuilds its contents when its key changes
 * @parent: what the contents are built on
 * @build: called with (@parent, data), returning the one object that owns
 *	   everything it made, so the holder can delete it whole
 *
 * Eleven files wrote a signature, compared it, deleted a group and rebuilt it.
 * The signature is worth keeping, because it is the page's own knowledge of
 * which fields change the shape. The rest of it is here.
 *
 * Return: a handle carrying obj, key and set(). set() answers whether it
 * rebuilt, so a caller with per tick values knows when not to push them.
 */
export function keyed_new(parent, build) {
	let holder = { key: null };

	holder.set = function(key, data) {
		if (holder.obj && holder.key == key)
			return false;

		holder.key = key;

		if (holder.obj)
			holder.obj.delete();

		holder.obj = build(parent, data);

		return true;
	};

	return holder;
};
