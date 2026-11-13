#!/usr/bin/env node
/*
	assets.js - the register of every asset that was made or taken from outside and put on Roblox (docs/Pipelines.md).

	Why a register. An upload is PERMANENT (Open Cloud cannot delete a model or an image; only the Creator Dashboard can), and some
	sources want a credit (CC-BY). So nothing goes on Roblox without a line in assets/manifest.json saying where it came from,
	under what licence, what it is, and who uses it. The game reads its ids from configs/ (as it always did); this file is the
	memory behind them.

	Usage (from the project folder):
	  node tools/assets.js list [--class image]
	  node tools/assets.js check                     validates the register; exits 1 on a problem
	  node tools/assets.js add --name castle_wall_color --class image --id rbxassetid://123 --tool "Poly Haven" \
	       --url https://polyhaven.com/a/castle_wall_varriation --licence CC0 --author "Rob Tuytel" \
	       --file assets/Materials/castle_wall_varriation/color_1k.jpg --used-by configs/Materials.luau
	  node tools/assets.js import-itemart            adds the 20 item meshes and textures of configs/ItemArt.luau (once)
	  node tools/assets.js find <text>               searches names, ids and notes
*/
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const FILE = path.join(ROOT, "assets", "manifest.json");
const CLASSES = ["model", "mesh", "image", "texture", "material", "audio", "animation", "icon", "ui", "vfx"];
const LICENCES = ["own", "generated", "CC0", "CC-BY", "Roblox"];

function load() {
	return JSON.parse(fs.readFileSync(FILE, "utf8"));
}
function save(m) {
	fs.writeFileSync(FILE, JSON.stringify(m, null, 2) + "\n");
}
function flags(argv) {
	const out = { _: [] };
	for (let i = 0; i < argv.length; i++) {
		if (argv[i].startsWith("--")) {
			const key = argv[i].slice(2);
			const next = argv[i + 1];
			if (next === undefined || next.startsWith("--")) out[key] = true;
			else {
				out[key] = next;
				i++;
			}
		} else out._.push(argv[i]);
	}
	return out;
}

function problems(m) {
	const bad = [];
	const names = new Set();
	const ids = new Set();
	for (const a of m.assets) {
		const label = `${a.class}/${a.name}`;
		for (const f of ["name", "class", "licence", "source"]) if (!a[f]) bad.push(`${label}: missing "${f}"`);
		if (a.class && !CLASSES.includes(a.class)) bad.push(`${label}: class "${a.class}" is not one of ${CLASSES.join(", ")}`);
		if (a.licence && !LICENCES.includes(a.licence)) bad.push(`${label}: licence "${a.licence}" is not one of ${LICENCES.join(", ")}`);
		if (a.licence === "CC-BY" && !a.credit) bad.push(`${label}: CC-BY needs a "credit" line`);
		if (a.id != null && !/^rbxassetid:\/\/\d+$/.test(a.id)) bad.push(`${label}: id "${a.id}" is not rbxassetid://<digits>`);
		if (a.id) {
			if (ids.has(a.id)) bad.push(`${label}: id ${a.id} is listed twice`);
			ids.add(a.id);
		}
		const key = `${a.class}/${a.name}`;
		if (names.has(key)) bad.push(`${label}: listed twice`);
		names.add(key);
		if (a.file && !fs.existsSync(path.join(ROOT, a.file))) bad.push(`${label}: file ${a.file} is not in the repository`);
	}
	return bad;
}

const [cmd, ...rest] = process.argv.slice(2);
const args = flags(rest);
const m = load();

if (cmd === "list") {
	const rows = m.assets.filter((a) => !args.class || a.class === args.class);
	for (const a of rows) console.log(`${a.class.padEnd(9)} ${a.name.padEnd(34)} ${(a.id || "(not uploaded)").padEnd(28)} ${a.licence}  <- ${a.source.tool}`);
	console.log(`${rows.length} asset(s)`);
} else if (cmd === "check") {
	const bad = problems(m);
	if (bad.length) {
		console.error(bad.join("\n"));
		console.error(`${bad.length} problem(s)`);
		process.exit(1);
	}
	console.log(`OK: ${m.assets.length} asset(s), every one has a source and a licence`);
} else if (cmd === "find") {
	const q = String(args._[0] || "").toLowerCase();
	for (const a of m.assets) if (JSON.stringify(a).toLowerCase().includes(q)) console.log(JSON.stringify(a));
} else if (cmd === "add") {
	const a = {
		name: args.name,
		class: args.class,
		id: args.id || null,
		source: { tool: args.tool, url: args.url || undefined, author: args.author || undefined },
		licence: args.licence,
		credit: args.credit || undefined,
		file: args.file || undefined,
		uploadedAt: args.id ? new Date().toISOString().slice(0, 10) : undefined,
		owner: args.id ? args.owner || "group:32361153" : undefined,
		usedBy: args["used-by"] ? String(args["used-by"]).split(",") : [],
		note: args.note || undefined,
	};
	const next = { ...m, assets: [...m.assets, a] };
	const bad = problems(next);
	if (bad.length) {
		console.error(bad.join("\n"));
		process.exit(1);
	}
	save(next);
	console.log(`added ${a.class}/${a.name}`);
} else if (cmd === "import-itemart") {
	const text = fs.readFileSync(path.join(ROOT, "configs", "ItemArt.luau"), "utf8");
	const re = /(\w+)\s*=\s*\{\s*Mesh\s*=\s*"(rbxassetid:\/\/\d+)"\s*,\s*Texture\s*=\s*"(rbxassetid:\/\/\d+)"/g;
	let match;
	let added = 0;
	const have = new Set(m.assets.map((a) => a.id));
	while ((match = re.exec(text))) {
		const [, key, mesh, texture] = match;
		for (const [cls, id, suffix] of [["mesh", mesh, "mesh"], ["image", texture, "texture"]]) {
			if (have.has(id)) continue;
			m.assets.push({
				name: `item_${key}_${suffix}`,
				class: cls,
				id,
				source: { tool: "Roblox Studio generate_mesh", url: "docs/systems/ItemArt.md" },
				licence: "generated",
				uploadedAt: "2026-10-25",
				owner: "group:32361153",
				usedBy: ["configs/ItemArt.luau"],
			});
			added++;
		}
	}
	const bad = problems(m);
	if (bad.length) {
		console.error(bad.join("\n"));
		process.exit(1);
	}
	save(m);
	console.log(`imported ${added} asset(s) from configs/ItemArt.luau`);
} else {
	console.log(fs.readFileSync(__filename, "utf8").split("*/")[0].replace(/^#!.*\n\/\*\n/, ""));
}
