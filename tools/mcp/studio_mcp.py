"""Minimal MCP stdio client for Roblox Studio's built-in StudioMCP.exe.

Usage:
  python studio_mcp.py list
  python studio_mcp.py call <tool_name> '<json args>'
  python studio_mcp.py call <tool_name> @args.json
  python studio_mcp.py run <file.lua>          # shortcut: run_code with file contents
"""
import glob
import json
import os
import queue
import subprocess
import sys
import threading

sys.stdout.reconfigure(encoding="utf-8")

VERSIONS = os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "Versions")


def find_exe():
    exes = glob.glob(os.path.join(VERSIONS, "*", "StudioMCP.exe"))
    if not exes:
        sys.exit("StudioMCP.exe not found")
    return max(exes, key=os.path.getmtime)


class Client:
    def __init__(self):
        self.p = subprocess.Popen(
            [find_exe()],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.q = queue.Queue()
        self.next_id = 1
        threading.Thread(target=self._read, daemon=True).start()
        threading.Thread(target=self._err, daemon=True).start()
        self.stderr = []

    def _read(self):
        for line in self.p.stdout:
            line = line.decode("utf-8", "replace").strip()
            if line:
                try:
                    self.q.put(json.loads(line))
                except json.JSONDecodeError:
                    self.stderr.append("[stdout non-json] " + line)

    def _err(self):
        for line in self.p.stderr:
            self.stderr.append(line.decode("utf-8", "replace").rstrip())

    def send(self, msg):
        self.p.stdin.write((json.dumps(msg) + "\n").encode("utf-8"))
        self.p.stdin.flush()

    def request(self, method, params=None, timeout=120):
        rid = self.next_id
        self.next_id += 1
        msg = {"jsonrpc": "2.0", "id": rid, "method": method}
        if params is not None:
            msg["params"] = params
        self.send(msg)
        while True:
            try:
                resp = self.q.get(timeout=timeout)
            except queue.Empty:
                raise TimeoutError(f"no response to {method} after {timeout}s")
            if resp.get("id") == rid:
                return resp

    def init(self):
        r = self.request(
            "initialize",
            {
                "protocolVersion": "2025-06-18",
                "capabilities": {},
                "clientInfo": {"name": "claude-code-bridge", "version": "1.0"},
            },
            timeout=30,
        )
        self.send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        return r

    def close(self):
        try:
            self.p.stdin.close()
            self.p.terminate()
        except Exception:
            pass


def show(resp):
    if "error" in resp:
        print("ERROR:", json.dumps(resp["error"], indent=2, ensure_ascii=False))
        return
    res = resp.get("result", {})
    if "content" in res:
        import base64, time
        for c in res["content"]:
            if c.get("type") == "image":
                ext = "png" if "png" in c.get("mimeType", "png") else "jpg"
                fn = os.path.join(os.path.dirname(os.path.abspath(__file__)), f"cap_{int(time.time()*1000)}.{ext}")
                open(fn, "wb").write(base64.b64decode(c["data"]))
                print("IMAGE:", fn)
            else:
                print(c.get("text", json.dumps(c, ensure_ascii=False)))
        if res.get("isError"):
            print("(isError = true)")
    else:
        print(json.dumps(res, indent=2, ensure_ascii=False))


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    c = Client()
    try:
        init = c.init()
        cmd = sys.argv[1]
        if cmd == "init":
            print(json.dumps(init, indent=2, ensure_ascii=False))
        elif cmd == "list":
            r = c.request("tools/list", {})
            for t in r.get("result", {}).get("tools", []):
                print("==", t["name"])
                print(t.get("description", "").strip())
                print("   args:", json.dumps(t.get("inputSchema", {}).get("properties", {}), ensure_ascii=False))
                print()
        elif cmd == "studios":
            import time
            for _ in range(20):
                r = c.request("tools/call", {"name": "list_roblox_studios", "arguments": {}}, timeout=60)
                txt = "".join(x.get("text", "") for x in r.get("result", {}).get("content", []))
                if '"studios":[]' not in txt.replace(" ", ""):
                    break
                time.sleep(1.5)
            print(txt)
        elif cmd in ("call", "run"):
            if cmd == "run":
                with open(sys.argv[2], encoding="utf-8") as f:
                    name, args = "run_code", {"command": f.read()}
            else:
                name, raw = sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "{}"
                if raw.startswith("@"):
                    with open(raw[1:], encoding="utf-8") as f:
                        raw = f.read()
                args = json.loads(raw)
            import time
            if os.environ.get("STUDIO_ID") and name != "list_roblox_studios":
                args.setdefault("studio_id", os.environ["STUDIO_ID"])
            for attempt in range(15):
                r = c.request("tools/call", {"name": name, "arguments": args}, timeout=600)
                txt = json.dumps(r)
                if "No Roblox Studio instances" in txt or "No studio available" in txt or "missing the required `studio_id`" in txt and not os.environ.get("STUDIO_ID"):
                    time.sleep(2)
                    continue
                break
            show(r)
        else:
            sys.exit(__doc__)
    finally:
        c.close()
        if c.stderr:
            print("--- server stderr ---", file=sys.stderr)
            print("\n".join(c.stderr[-20:]), file=sys.stderr)


if __name__ == "__main__":
    main()
