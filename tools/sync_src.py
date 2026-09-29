"""Copia el codi de src/ a Roblox Studio via MCP, amb les mateixes regles que Rojo.

Us (des de l'arrel del projecte, amb Studio obert):
    python tools/sync_src.py

Per treballar dia a dia val mes `rojo serve` + el plugin de Rojo (Connect).
Aquest script es per quan no hi ha Rojo connectat: fa una copia completa
(esborra i torna a crear les tres arrels), segons default.project.json.

Regles (les de Rojo):
    carpeta               -> Folder
    init.server.luau      -> la carpeta es torna Script
    init.client.luau      -> la carpeta es torna LocalScript
    init.luau             -> la carpeta es torna ModuleScript
    X.server.luau / X.client.luau / X.luau -> Script / LocalScript / ModuleScript
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BRIDGE = os.path.join(ROOT, "tools", "mcp", "studio_mcp.py")

KINDS = [(".server.luau", "Script"), (".client.luau", "LocalScript"), (".luau", "ModuleScript"),
         (".server.lua", "Script"), (".client.lua", "LocalScript"), (".lua", "ModuleScript")]


def script_kind(filename):
    for ext, cls in KINDS:
        if filename.endswith(ext):
            return filename[: -len(ext)], cls
    return None, None


def read(path):
    return open(path, encoding="utf-8").read()


def node_for_dir(path, name):
    node = {"name": name, "class": "Folder", "children": []}
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            node["children"].append(node_for_dir(full, entry))
            continue
        base, cls = script_kind(entry)
        if cls is None:
            continue
        if base == "init":
            node["class"] = cls
            node["source"] = read(full)
        else:
            node["children"].append({"name": base, "class": cls, "source": read(full), "children": []})
    return node


def collect_targets():
    """Llegeix default.project.json i torna [(cami a Studio, node)]."""
    project = json.load(open(os.path.join(ROOT, "default.project.json"), encoding="utf-8"))
    out = []

    def walk(tree, path):
        for key, value in tree.items():
            if key.startswith("$") or not isinstance(value, dict):
                continue
            if "$path" in value:
                out.append((path + [key], node_for_dir(os.path.join(ROOT, value["$path"]), key)))
            else:
                walk(value, path + [key])

    walk(project["tree"], [])
    return out


def long_string(text):
    level = 1
    while ("]" + "=" * level + "]") in text:
        level += 1
    eq = "=" * level
    return "[" + eq + "[\n" + text + "]" + eq + "]"


def emit(node, parent_var, lines, counter):
    counter[0] += 1
    var = f"n{counter[0]}"
    lines.append(f'local {var} = Instance.new("{node["class"]}")')
    lines.append(f"{var}.Name = {json.dumps(node['name'])}")
    if "source" in node:
        lines.append(f"{var}.Source = {long_string(node['source'])}")
    for child in node["children"]:
        emit(child, var, lines, counter)
    lines.append(f"{var}.Parent = {parent_var}")


def build_payload(targets):
    lines = ["local count = 0", "local function at(path)",
             "\tlocal inst = game", "\tfor _, name in ipairs(path) do",
             "\t\tlocal nxt = inst:FindFirstChild(name)",
             "\t\tif not nxt then nxt = game:GetService(name) end",
             "\t\tinst = nxt", "\tend", "\treturn inst", "end"]
    counter = [0]
    for path, node in targets:
        parent_path = path[:-1]
        lines.append("do")
        lines.append(f"\tlocal parent = at({{{', '.join(json.dumps(p) for p in parent_path)}}})")
        lines.append(f"\tlocal old = parent:FindFirstChild({json.dumps(path[-1])})")
        lines.append("\tif old then old:Destroy() end")
        body = []
        emit(node, "parent", body, counter)
        lines.extend("\t" + b for b in body)
        lines.append("end")
    lines.append(f"return 'sincronitzats {counter[0]} objectes'")
    return "\n".join(lines)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    targets = collect_targets()
    payload = build_payload(targets)
    call = os.path.join(ROOT, "tools", "_sync_call.json")
    json.dump({"datamodel_type": "Edit", "code": payload}, open(call, "w", encoding="utf-8"))
    try:
        r = subprocess.run([sys.executable, BRIDGE, "call", "execute_luau", "@" + call],
                           capture_output=True, text=True, encoding="utf-8")
    finally:
        os.remove(call)
    for path, node in targets:
        print(" > " + ".".join(path))
    print(r.stdout.strip() or r.stderr.strip())


if __name__ == "__main__":
    main()
