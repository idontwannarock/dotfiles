#!/usr/bin/env python3
"""Minimal CDP driver for the Windows-side Chrome exposed via netsh portproxy.

Usage:
  cdp.py nav <url>                 navigate the first page target, print final url+title
  cdp.py eval '<js expression>'    evaluate JS in the page (awaits promises)
  cdp.py fetch <url>               fetch <url> from inside the page (cookies included), print body
  cdp.py get <url>                 navigate + print document.body.innerText
  cdp.py tabs                      list page targets

The Windows host is the WSL default gateway, which differs per machine and can
change across reboots -- detect it rather than hard-coding. Override with
CDP_HOST when running outside WSL or against a non-default address.
"""
import asyncio, json, os, re, subprocess, sys, urllib.request
import websockets


def default_gateway():
    out = subprocess.run(["ip", "route", "show", "default"],
                         capture_output=True, text=True).stdout
    m = re.search(r"default via (\S+)", out)
    if not m:
        raise SystemExit("cannot detect the WSL default gateway; set CDP_HOST")
    return m.group(1)


HOST = os.environ.get("CDP_HOST") or default_gateway()
CDP = f"http://{HOST}:9222"


def targets():
    with urllib.request.urlopen(CDP + "/json/list", timeout=10) as r:
        return json.load(r)


def page_ws():
    for t in targets():
        if t.get("type") == "page":
            # webSocketDebuggerUrl points at 127.0.0.1 (Windows loopback); rewrite to the gateway
            return t["webSocketDebuggerUrl"].replace("127.0.0.1", HOST).replace("localhost", HOST)
    raise SystemExit("no page target; is Chrome running with --remote-debugging-port=9222 ?")


class Session:
    def __init__(self, ws):
        self.ws, self.n = ws, 0

    async def call(self, method, params=None, timeout=120):
        self.n += 1
        mid = self.n
        await self.ws.send(json.dumps({"id": mid, "method": method, "params": params or {}}))
        while True:
            msg = json.loads(await asyncio.wait_for(self.ws.recv(), timeout))
            if msg.get("id") == mid:
                if "error" in msg:
                    raise RuntimeError(msg["error"])
                return msg.get("result", {})


async def run(action, arg):
    async with websockets.connect(page_ws(), max_size=200 * 1024 * 1024) as ws:
        s = Session(ws)
        if action == "nav":
            await s.call("Page.enable")
            await s.call("Page.navigate", {"url": arg})
            await asyncio.sleep(4)
            r = await s.call("Runtime.evaluate",
                             {"expression": "JSON.stringify({url:location.href,title:document.title})",
                              "returnByValue": True})
            print(r["result"]["value"])
        elif action == "eval":
            r = await s.call("Runtime.evaluate",
                             {"expression": arg, "awaitPromise": True, "returnByValue": True})
            res = r.get("result", {})
            if r.get("exceptionDetails"):
                print("EXCEPTION:", json.dumps(r["exceptionDetails"])[:500])
            else:
                print(res.get("value") if "value" in res else json.dumps(res)[:2000])
        elif action == "fetch":
            expr = ("(async()=>{const r=await fetch(%s,{credentials:'include'});"
                    "return JSON.stringify({status:r.status,body:(await r.text()).slice(0,200000)});})()"
                    % json.dumps(arg))
            r = await s.call("Runtime.evaluate",
                             {"expression": expr, "awaitPromise": True, "returnByValue": True})
            if r.get("exceptionDetails"):
                print("EXCEPTION:", json.dumps(r["exceptionDetails"])[:500])
            else:
                print(r["result"]["value"])
        elif action == "get":
            # navigate + read rendered text in a single session (avoids racing on tab order)
            await s.call("Page.enable")
            await s.call("Page.navigate", {"url": arg})
            for _ in range(40):
                await asyncio.sleep(0.5)
                r = await s.call("Runtime.evaluate",
                                 {"expression": "document.readyState==='complete' && !!document.body",
                                  "returnByValue": True})
                if r.get("result", {}).get("value"):
                    break
            await asyncio.sleep(1.5)
            r = await s.call("Runtime.evaluate",
                             {"expression": "document.body.innerText", "returnByValue": True})
            print(r.get("result", {}).get("value") or "")
        elif action == "tabs":
            for t in targets():
                print(f"{t.get('type'):<10} {t.get('title','')[:40]:<40} {t.get('url','')[:70]}")


if __name__ == "__main__":
    a = sys.argv[1] if len(sys.argv) > 1 else "tabs"
    b = sys.argv[2] if len(sys.argv) > 2 else ""
    asyncio.run(run(a, b))
