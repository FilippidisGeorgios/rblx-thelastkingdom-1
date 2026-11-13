#!/usr/bin/env node
/*
	polyhaven.js - fetches the maps of one Poly Haven texture (CC0) into assets/Materials/<id>/ for the material pipeline
	(docs/Pipelines.md, pipeline 2).

	Usage:   node tools/textures/polyhaven.js rock_wall_08 [--res 1k] [--maps Diffuse,nor_gl,Rough]
	Finds ids with the Blender MCP's search_assets (source polyhaven) or at https://polyhaven.com/textures.

	Writes  assets/Materials/<id>/<map>_<res>.<ext>  and  SOURCE.txt (url, author, licence, date).
	Poly Haven is CC0: no credit is needed, but SOURCE.txt keeps it anyway. Roblox reads OpenGL normal maps (nor_gl), a
	greyscale roughness map and a colour map; 1k (1024 px) is plenty for a wall seen at a stud, and is the biggest the
	Low graphics setting should have to hold.
*/
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..", "..");
const API = "https://api.polyhaven.com";
const HEADERS = { "User-Agent": "tlk-asset-tool (medieval Roblox game; texture fetch)" };

function flags(argv) {
	const out = { _: [] };
	for (let i = 0; i < argv.length; i++) {
		if (argv[i].startsWith("--")) {
			out[argv[i].slice(2)] = argv[i + 1];
			i++;
		} else out._.push(argv[i]);
	}
	return out;
}

async function getJson(url) {
	const r = await fetch(url, { headers: HEADERS });
	if (!r.ok) throw new Error(`${r.status} ${r.statusText} for ${url}`);
	return r.json();
}

(async () => {
	const args = flags(process.argv.slice(2));
	const id = args._[0];
	if (!id) {
		console.log(fs.readFileSync(__filename, "utf8").split("*/")[0].replace(/^#!.*\n\/\*\n/, ""));
		return;
	}
	const res = args.res || "1k";
	const wanted = (args.maps || "Diffuse,nor_gl,Rough").split(",");

	const info = await getJson(`${API}/info/${id}`);
	const files = await getJson(`${API}/files/${id}`);
	const outDir = path.join(ROOT, "assets", "Materials", id);
	fs.mkdirSync(outDir, { recursive: true });

	const got = [];
	for (const map of wanted) {
		const level = files[map] && files[map][res];
		if (!level) {
			console.error(`  ${map}: no ${res} version (has: ${files[map] ? Object.keys(files[map]).join(", ") : "none"})`);
			continue;
		}
		const ext = level.jpg ? "jpg" : level.png ? "png" : null;
		if (!ext) {
			console.error(`  ${map}: ${res} comes only as ${Object.keys(level).join(", ")}`);
			continue;
		}
		const url = level[ext].url;
		const bytes = Buffer.from(await (await fetch(url, { headers: HEADERS })).arrayBuffer());
		const file = path.join(outDir, `${map}_${res}.${ext}`);
		fs.writeFileSync(file, bytes);
		got.push(`${path.relative(ROOT, file).replace(/\\/g, "/")} (${(bytes.length / 1024).toFixed(0)} KB)`);
	}

	const author = info.authors ? Object.keys(info.authors).join(", ") : "unknown";
	fs.writeFileSync(
		path.join(outDir, "SOURCE.txt"),
		[
			`${info.name} (${id})`,
			`Source:   https://polyhaven.com/a/${id}`,
			`Author:   ${author}`,
			`Licence:  CC0 1.0 (public domain; no credit needed)`,
			`Size:     ${info.dimensions ? info.dimensions.map((d) => (d / 1000).toFixed(2) + " m").join(" x ") : "see the page"} (one tile)`,
			`Fetched:  ${new Date().toISOString().slice(0, 10)} with tools/textures/polyhaven.js, resolution ${res}`,
			`Maps:     ${got.join("; ")}`,
			"",
		].join("\n"),
	);
	console.log(`${info.name} by ${author}, CC0`);
	got.forEach((g) => console.log("  " + g));
})().catch((e) => {
	console.error(e.message);
	process.exit(1);
});
