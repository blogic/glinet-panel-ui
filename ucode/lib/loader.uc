'use strict';

import * as ubus from 'ubus';
import * as uci from 'uci';

const PAGE_DIR = '/usr/share/ucode/glinet-panel-ui/pages';
const SUB_DIR = '/usr/share/ucode/glinet-panel-ui/subpages';
const TEMPLATE_DIR = '/usr/share/ucode/glinet-panel-ui/templates';

let published;
let configured;

function published_read() {
	try {
		return ubus.list() ?? [];
	}
	catch (e) {
		return [];
	}
}

function configured_read() {
	let cursor = uci.cursor();
	let found = {};

	if (!cursor.load('glinet_panel'))
		return found;

	for (let option, value in cursor.get_all('glinet_panel', '@panel[0]') ?? {})
		if (value != null && value != '')
			found[option] = true;

	return found;
}

function requires_met(page) {
	let wanted = page.requires;

	if (wanted == null)
		return true;

	published ??= published_read();

	for (let object in type(wanted) == 'array' ? wanted : [ wanted ])
		if (index(published, object) < 0)
			return false;

	return true;
}

function options_met(page) {
	let wanted = page.requires_option;

	if (wanted == null)
		return true;

	configured ??= configured_read();

	for (let option in type(wanted) == 'array' ? wanted : [ wanted ])
		if (!configured[option])
			return false;

	return true;
}

function page_read(path, name) {
	let page;

	try {
		let entry = loadfile(path);

		page = entry ? entry() : null;
	}
	catch (e) {
		warn(sprintf('panel: page %s failed to load: %s\n', name, e));

		return null;
	}

	if (type(page) != 'object' || type(page.build) != 'function') {
		warn(sprintf('panel: page %s returned no builder\n', name));

		return null;
	}

	if (!requires_met(page) || !options_met(page))
		return null;

	page.needs ??= [];
	page.name = name;

	return page;
}

/**
 * page_load - load a root page by name
 * @name: the name from the uci pages list
 * @section: its config page section, for a template instance, else null
 *
 * Return: the page object, or null when it will not load, its ubus object is
 * absent, or an option it names is not set.
 */
export function page_load(name, section) {
	if (section && !section.template) {
		warn(sprintf('panel: page %s names no template\n', name));

		return null;
	}

	let path = section
		? sprintf('%s/%s.uc', TEMPLATE_DIR, section.template)
		: sprintf('%s/%s.uc', PAGE_DIR, name);
	let page = page_read(path, name);

	if (page)
		page.config = section;

	return page;
};

/**
 * subpage_load - load a sub page by name
 * @name: the file name under subpages/, without the extension
 *
 * Return: the page object, or null.
 */
export function subpage_load(name) {
	return page_read(sprintf('%s/%s.uc', SUB_DIR, name), name);
};

/**
 * pages_load - load the root set
 * @names: page names, in the order they are shown
 * @sections: config page sections, keyed by name
 *
 * Return: the pages that loaded, in order. A page that did not is left out.
 */
export function pages_load(names, sections) {
	let loaded = [];

	for (let name in names) {
		let page = page_load(name, sections[name]);

		if (page)
			push(loaded, page);
	}

	return loaded;
};
