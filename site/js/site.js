/* Chiip's website: the only script. It fills in the download buttons and the release notes from
   GitHub's public releases API, so a new release shows up here with no edit to the site. Without
   JavaScript, or when the API can't be reached (offline, rate-limited, no release yet), every
   button keeps the plain link to the latest release that is written in the HTML. */
"use strict";

/* The repository this site belongs to: the only place its name is written in a script. */
const REPO = "Jankozeluh/Chiip";
const API = "https://api.github.com/repos/" + REPO;
const CACHE_MS = 10 * 60 * 1000;

/* Which release file is for which system: matched against the file names in the release. */
const SYSTEMS = {
	windows: { label: "Windows", pattern: /windows/i },
	mac: { label: "macOS", pattern: /mac/i },
	linux: { label: "Linux", pattern: /linux/i },
};

/* --- Reading the API, remembered for ten minutes (the API allows 60 requests an hour) ---------- */

async function getJson(path) {
	const key = "chiip-api:" + path;
	try {
		const stored = JSON.parse(sessionStorage.getItem(key) || "null");
		if (stored && Date.now() - stored.at < CACHE_MS) {
			return stored.data;
		}
	} catch (error) { /* storage may be blocked: carry on without it */ }
	const response = await fetch(API + path, { headers: { Accept: "application/vnd.github+json" } });
	if (!response.ok) {
		throw new Error("GitHub answered " + response.status);
	}
	const data = await response.json();
	try {
		sessionStorage.setItem(key, JSON.stringify({ at: Date.now(), data: data }));
	} catch (error) { /* ignore */ }
	return data;
}

function visitorSystem() {
	const agent = (navigator.userAgent || "") + " " + (navigator.platform || "");
	if (/android|iphone|ipad|ipod/i.test(agent)) return "";
	if (/win/i.test(agent) && !/darwin/i.test(agent)) return "windows";
	if (/mac/i.test(agent)) return "mac";
	if (/linux|x11|cros/i.test(agent)) return "linux";
	return "";
}

function assetFor(release, system) {
	const pattern = SYSTEMS[system].pattern;
	return (release.assets || []).find(function (asset) { return pattern.test(asset.name) && /\.zip$/i.test(asset.name); });
}

function megabytes(bytes) {
	return (bytes / 1048576).toFixed(0) + " MB";
}

function dateText(iso) {
	const date = new Date(iso);
	return isNaN(date) ? "" : date.toLocaleDateString("en-GB", { day: "numeric", month: "long", year: "numeric" });
}

/* --- Download buttons --------------------------------------------------------------------------- */

async function fillDownloads() {
	const boxes = document.querySelectorAll("[data-system]");
	const versions = document.querySelectorAll("[data-version]");
	const hero = document.querySelector("[data-download-link]");
	if (!boxes.length && !versions.length && !hero) return;
	let release;
	try {
		release = await getJson("/releases/latest");
	} catch (error) {
		versions.forEach(function (node) { node.textContent = node.dataset.fallback || ""; });
		return;
	}
	const mine = visitorSystem();
	versions.forEach(function (node) {
		node.textContent = "Latest: " + release.tag_name + (release.published_at ? " · " + dateText(release.published_at) : "");
	});
	boxes.forEach(function (box) {
		const system = box.dataset.system;
		const asset = SYSTEMS[system] ? assetFor(release, system) : null;
		const button = box.querySelector("a.button");
		const meta = box.querySelector(".meta");
		if (asset && button) {
			button.href = asset.browser_download_url;
			if (meta) meta.textContent = asset.name + " · " + megabytes(asset.size);
		}
		if (system === mine) {
			box.classList.add("yours");
			const badge = box.querySelector(".badge");
			if (badge) badge.hidden = false;
		}
	});
	if (hero && mine && SYSTEMS[mine]) {
		const asset = assetFor(release, mine);
		if (asset) {
			hero.href = asset.browser_download_url;
			hero.textContent = "Download for " + SYSTEMS[mine].label;
		}
	}
}

/* --- Release notes: GitHub's markdown, shown as plain HTML --------------------------------------- */

function escapeHtml(text) {
	return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

/* Inline markdown on text that is already escaped: `code`, **bold**, [text](url) and bare links. */
function inline(escaped) {
	return escaped
		.split("`")
		.map(function (part, index) {
			if (index % 2 === 1) return "<code>" + part + "</code>";
			return part
				.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
				.replace(/\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/g, '<a href="$2" rel="noopener">$1</a>')
				.replace(/&lt;(https?:\/\/[^\s&]+)&gt;/g, '<a href="$1" rel="noopener">$1</a>');
		})
		.join("");
}

/* The markdown a release's notes use: headings, bullet and numbered lists, tables and paragraphs. */
function markdown(source) {
	const lines = String(source || "").replace(/\r/g, "").split("\n");
	const out = [];
	let paragraph = [];
	let list = "";
	let table = [];
	function endParagraph() {
		if (paragraph.length) out.push("<p>" + inline(escapeHtml(paragraph.join(" "))) + "</p>");
		paragraph = [];
	}
	function endList() {
		if (list) out.push("</" + list + ">");
		list = "";
	}
	function endTable() {
		if (!table.length) return;
		const rows = table.map(function (row) { return row.replace(/^\||\|$/g, "").split("|").map(function (cell) { return cell.trim(); }); });
		const body = rows.slice(2);
		out.push("<table><thead><tr>" + rows[0].map(function (c) { return "<th>" + inline(escapeHtml(c)) + "</th>"; }).join("") + "</tr></thead><tbody>"
			+ body.map(function (r) { return "<tr>" + r.map(function (c) { return "<td>" + inline(escapeHtml(c)) + "</td>"; }).join("") + "</tr>"; }).join("")
			+ "</tbody></table>");
		table = [];
	}
	lines.forEach(function (line) {
		const trimmed = line.trim();
		let match;
		if (/^\|/.test(trimmed)) {
			endParagraph(); endList();
			table.push(trimmed);
			return;
		}
		endTable();
		if (!trimmed) { endParagraph(); endList(); return; }
		if ((match = /^(#{1,4})\s+(.*)$/.exec(trimmed))) {
			endParagraph(); endList();
			const level = match[1].length >= 4 ? 4 : 3;
			out.push("<h" + level + ">" + inline(escapeHtml(match[2])) + "</h" + level + ">");
		} else if ((match = /^[-*]\s+(.*)$/.exec(trimmed))) {
			endParagraph();
			if (list !== "ul") { endList(); out.push("<ul>"); list = "ul"; }
			out.push("<li>" + inline(escapeHtml(match[1])) + "</li>");
		} else if ((match = /^\d+\.\s+(.*)$/.exec(trimmed))) {
			endParagraph();
			if (list !== "ol") { endList(); out.push("<ol>"); list = "ol"; }
			out.push("<li>" + inline(escapeHtml(match[1])) + "</li>");
		} else {
			endList();
			paragraph.push(trimmed);
		}
	});
	endParagraph(); endList(); endTable();
	return out.join("\n");
}

async function fillReleases() {
	const target = document.getElementById("releases");
	if (!target) return;
	let releases;
	try {
		releases = await getJson("/releases?per_page=30");
	} catch (error) {
		return;
	}
	const shown = releases.filter(function (release) { return !release.draft; });
	if (!shown.length) return;
	target.textContent = "";
	shown.forEach(function (release) {
		const section = document.createElement("article");
		section.className = "release";
		const heading = document.createElement("header");
		const title = document.createElement("h2");
		const link = document.createElement("a");
		link.href = release.html_url;
		link.rel = "noopener";
		link.textContent = release.name || release.tag_name;
		title.appendChild(link);
		const time = document.createElement("time");
		time.dateTime = release.published_at || "";
		time.textContent = dateText(release.published_at) + (release.prerelease ? " · pre-release" : "");
		heading.appendChild(title);
		heading.appendChild(time);
		const body = document.createElement("div");
		body.className = "doc";
		body.innerHTML = markdown(release.body);
		section.appendChild(heading);
		section.appendChild(body);
		target.appendChild(section);
	});
}

fillDownloads();
fillReleases();
