"""Empaqueta el constructor del món com a plugin local de Roblox Studio.

Ús:  python tools/world/make_plugin.py
Escriu %LOCALAPPDATA%/Roblox/Plugins/MuseuDeFossils_Mon.lua (i una còpia a tools/world/dist/).
Studio el carrega en obrir-se: pestanya PLUGINS → "Construir el món".
"""
import glob
import os

HERE = os.path.dirname(os.path.abspath(__file__))
lib = open(os.path.join(HERE, "lib.luau"), encoding="utf-8").read()
mods = sorted(glob.glob(os.path.join(HERE, "[0-9][0-9]_*.luau")))

out = ['''--[[ ═══════════════════════════════════════════════════════════════════════
     MUSEU DE FÒSSILS · constructor del món (plugin)
     Pestanya PLUGINS → botó "Construir el món".

     Esborra el món anterior (Workspace.World, Zones, Museums i el terreny)
     i el torna a fer: plaça amb el T-Rex, 8 museus, cases, platja, Zona 1
     (obra), parcs i carrers. NO toca els scripts del joc.
     Es pot desfer amb Ctrl+Z. Recorda desar (Ctrl+S) quan t'agradi.

     Generat per tools/world/make_plugin.py — no l'editis a mà, edita els
     mòduls de tools/world/ i torna'l a generar.
     ═══════════════════════════════════════════════════════════════════════ ]]

local function BuildWorld()
''']
out.append(lib)
out.append("\n\tlocal STEPS = {}\n")
for m in mods:
    name = os.path.basename(m)[:-5]
    out.append(f'STEPS[#STEPS + 1] = {{ "{name}", function()\n' + open(m, encoding="utf-8").read() + "\nend }\n")
out.append('''
	for i, s in ipairs(STEPS) do
		print(("[Món] %d/%d %s..."):format(i, #STEPS, s[1]))
		local ok, err = pcall(s[2])
		if not ok then
			warn("[Món] error a " .. s[1] .. ": " .. tostring(err))
		end
		task.wait()
	end
end

local CHS = game:GetService("ChangeHistoryService")
local toolbar = plugin:CreateToolbar("Museu de Fòssils · Món")
local button = toolbar:CreateButton("Construir el món", "Construeix el món nou sencer (esborra l'anterior)", "rbxasset://textures/StudioToolbox/AssetPreview/Rating_Up.png")
button.ClickableWhenViewportHidden = true
local busy = false
button.Click:Connect(function()
	if busy then
		return
	end
	busy = true
	local rec = CHS:TryBeginRecording("Construir el món")
	local t0 = os.clock()
	local ok, err = pcall(BuildWorld)
	if not ok then
		warn("[Món] " .. tostring(err))
	end
	if rec then
		CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
	end
	print(("[Món] Fet en %.1f s. Desa amb Ctrl+S!"):format(os.clock() - t0))
	button:SetActive(false)
	busy = false
end)
''')
src = "".join(out)
os.makedirs(os.path.join(HERE, "dist"), exist_ok=True)
open(os.path.join(HERE, "dist", "MuseuDeFossils_Mon.lua"), "w", encoding="utf-8").write(src)
dst = os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "Plugins", "MuseuDeFossils_Mon.lua")
open(dst, "w", encoding="utf-8").write(src)
print(dst, len(src) // 1024, "KB,", len(mods), "mòduls")
