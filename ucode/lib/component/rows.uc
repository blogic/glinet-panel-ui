'use strict';

import { SEP_H, ROW_H } from '../theme.uc';
import { group_new, row_new, row_sep_new, row_stacked_new, row_stacked_height,
	 empty_new } from '../widget.uc';

/**
 * rows_new - a list of rows that rebuilds itself when its key changes
 * @parent: the page's scroll area, from list_new()
 * @opts: empty, the one line to show in place of no rows; h, the row height,
 *	  defaulting to the sub page tier; large, for the root tier faces; y,
 *	  the top edge inside the scroll area; activity, the page's handler
 *
 * Return: a handle carrying rows, the entries, so a page can change a value in
 * place; and set().
 */
export function rows_new(parent, opts) {
	let o = opts ?? {};
	let h = o.h ?? ROW_H;
	let list = { rows: [], key: null };

	/**
	 * set - build the rows, if the key says they are not the ones shown
	 * @key: what the shape depends on, from key_of()
	 * @items: the models, one per row
	 * @row_of: called with (item, index), returning the row_new() options.
	 *	    A row that carries stacked takes the caption above value form
	 *	    and measures its own height; any row may name its own h.
	 *
	 * Return: true where it rebuilt, so a caller with per tick values to
	 * push knows when not to.
	 */
	list.set = function(key, items, row_of) {
		if (list.obj && list.key == key)
			return false;

		list.key = key;
		list.rows = [];

		if (list.obj)
			list.obj.delete();

		let count = length(items);

		if (!count) {
			list.obj = empty_new(parent, o.empty);

			return true;
		}

		/* Heights first: the group is sized before it is filled. */
		let specs = [];
		let total = (count - 1) * SEP_H;

		for (let i = 0; i < count; i++) {
			let spec = row_of(items[i], i);

			spec.h ??= spec.stacked ? row_stacked_height(spec.value, h)
						: h;

			push(specs, spec);
			total += spec.h;
		}

		list.obj = group_new(parent, o.y ?? 0, total, o.activity);

		let top = 0;

		for (let i = 0; i < count; i++) {
			let spec = specs[i];

			if (spec.stacked)
				push(list.rows,
				     { obj: row_stacked_new(list.obj, top,
							    spec.caption,
							    spec.value, spec.h) });
			else
				push(list.rows,
				     row_new(list.obj, top,
					     { ...spec, large: o.large,
					       activity: o.activity }));

			top += spec.h;

			if (i + 1 >= count)
				continue;

			row_sep_new(list.obj, top);
			top += SEP_H;
		}

		return true;
	};

	return list;
};
