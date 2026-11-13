<#
	StartBlenderMcp.ps1 - opens Blender 5.3 with the MCP add-on enabled and its server listening (port 9876).

	Usage:   powershell -File tools\blender\StartBlenderMcp.ps1

	WHY A SCRIPT. Blender 5.x does not list a legacy add-on (a single .py in scripts\addons) in Preferences > Add-ons, and the
	add-on's sidebar panel does not appear by itself, so the usual "tick it, press Start" does not work. Enabling it from a
	startup script does: the add-on then starts its server on its own (it has an auto-start). Verified 2026-11-13: after this,
	`get_addon_status` of the `blender` MCP answers and port 9876 listens.

	The add-on file comes from `uvx mcp-for-blender install-addon --addons-dir "<Blender>\scripts\addons"` (it lands as
	blender_mcp.py). Claude's `blender` MCP server (registered with `claude mcp add`, telemetry off, safe mode on) talks to it.

	NOTE. Claude's desktop extension called "Blender" also uses port 9876 and a different protocol: while this add-on listens
	its tools time out. Use the `blender` tools (mcp-for-blender), or disable that extension for the session.
	Poly Haven is switched on per session from Claude (`bpy.context.scene.blendermcp_use_polyhaven = True`); it is a scene
	property, so it is off again in a new Blender.
#>
$blender = "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe"
if (-not (Test-Path $blender)) { throw "Blender 5.3 is not at $blender" }

$py = Join-Path $env:TEMP "tlk_blender_enable_mcp.py"
Set-Content -Path $py -Encoding utf8 -Value @'
import bpy, addon_utils
addon_utils.enable("blender_mcp", default_set=True, persistent=True)
bpy.ops.wm.save_userpref()
print("TLK: blender_mcp enabled at startup")
'@

Start-Process -FilePath $blender -ArgumentList "--python", $py
for ($i = 0; $i -lt 20; $i++) {
	Start-Sleep -Seconds 1
	if (Get-NetTCPConnection -LocalPort 9876 -State Listen -ErrorAction SilentlyContinue) {
		"Blender is listening on 9876."
		return
	}
}
"Blender started but nothing listens on 9876 yet; give it a few more seconds."
