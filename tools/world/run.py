"""Construeix el món a Roblox Studio via MCP.

Ús (des de l'arrel del projecte):
    python tools/world/run.py            # tots els mòduls, per ordre
    python tools/world/run.py 03 04      # només els que comencen per 03 i 04
Cada mòdul s'envia amb lib.luau al davant. Els print del mòdul tornen aquí.
"""
import glob
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BRIDGE = os.path.join(HERE, "..", "mcp", "studio_mcp.py")
WRAP = """local src = [=====[%s]=====]
local out = {}
local function cap(prefix)
	return function(...)
		local t = {}
		for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
		table.insert(out, prefix .. table.concat(t, " "))
	end
end
local f, e = loadstring(src)
if not f then return "PARSE " .. tostring(e) end
setfenv(f, setmetatable({ print = cap(""), warn = cap("WARN ") }, { __index = getfenv() }))
local t0 = os.clock()
local ok, err = pcall(f)
return table.concat(out, " | ") .. (ok and "" or (" | ERROR " .. tostring(err))) .. (" | %%.1fs"):format(os.clock() - t0)
"""


def run_code(src):
    call = os.path.join(HERE, "_call.json")
    json.dump({"datamodel_type": "Edit", "code": WRAP % src}, open(call, "w", encoding="utf-8"))
    r = subprocess.run([sys.executable, BRIDGE, "call", "execute_luau", "@" + call], capture_output=True, text=True, encoding="utf-8")
    os.remove(call)
    return r.stdout.strip()


def main():
    lib = open(os.path.join(HERE, "lib.luau"), encoding="utf-8").read()
    mods = sorted(glob.glob(os.path.join(HERE, "[0-9][0-9]_*.luau")))
    if len(sys.argv) > 1:
        mods = [m for m in mods if any(os.path.basename(m).startswith(p) for p in sys.argv[1:])]
    for m in mods:
        src = lib + "\n" + open(m, encoding="utf-8").read()
        print(f"{os.path.basename(m):18s} {run_code(src)[:600]}", flush=True)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
