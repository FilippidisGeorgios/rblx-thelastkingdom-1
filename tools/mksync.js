// node tools/mksync.js <world|default>     (see tools/SyncFromBundle.luau)
// Builds ONE model file holding every script of a place's project (the same mapping Rojo uses) plus tools/, and puts it in
// Roblox Studio's own content folder under tlk_sync/, where an edit-mode script can load it with
//   game:GetObjects("rbxasset://tlk_sync/<name>.rbxm")
// (the Studio assistant's HTTP allowlist no longer lets a script read the dev server on 127.0.0.1).
// Each run writes a NEW file name (Studio caches by name) and removes the older ones. Prints the name to load.
const fs = require('fs'), path = require('path'), cp = require('child_process');
const repo = path.resolve(__dirname, '..') + path.sep;
const which = process.argv[2] || 'world';
const proj = JSON.parse(fs.readFileSync(path.join(repo, which + '.project.json'), 'utf8'));

const roots = [];
(function walk(node, segs) {
  for (const [k, v] of Object.entries(node)) {
    if (k.startsWith('$') || typeof v !== 'object') continue;
    const s = segs.concat([k]);
    if (v.$path) roots.push({ segs: s, dir: v.$path });
    walk(v, s);
  }
})(proj.tree, []);

const tree = { $className: 'Folder' };
for (const r of roots) {
  if (!fs.existsSync(path.join(repo, r.dir))) continue;
  tree[r.segs.join('.')] = { $path: r.dir };
}
tree['__Tools'] = { $path: 'tools' };
const syncProject = path.join(repo, '.tlk_sync.project.json');
fs.writeFileSync(syncProject, JSON.stringify({ name: 'TLKSync', tree }, null, 2));

const versions = path.join(process.env.LOCALAPPDATA, 'Roblox', 'Versions');
const studioDirs = fs.readdirSync(versions).filter(d => fs.existsSync(path.join(versions, d, 'RobloxStudioBeta.exe')));
if (studioDirs.length === 0) { console.error('no Studio install found'); process.exit(1); }
const stamp = Date.now().toString(36);
const name = `${which}_${stamp}`;
let built = null;
for (const d of studioDirs) {
  const dir = path.join(versions, d, 'content', 'tlk_sync');
  fs.mkdirSync(dir, { recursive: true });
  for (const old of fs.readdirSync(dir)) if (old.startsWith(which + '_')) fs.unlinkSync(path.join(dir, old));
  const out = path.join(dir, name + '.rbxm');
  if (!built) {
    cp.execFileSync('rojo', ['build', syncProject, '-o', out], { cwd: repo, stdio: ['ignore', 'pipe', 'pipe'] });
    built = out;
  } else {
    fs.copyFileSync(built, out);
  }
}
fs.unlinkSync(syncProject);
console.log(name + ' ' + fs.statSync(built).size + ' bytes, roots ' + roots.length);
