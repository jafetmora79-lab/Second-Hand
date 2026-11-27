// Opens the web build in a headless Chrome on the real GPU, prints its console (WEBDIAG lines and errors), and saves screenshots.
// Usage: node tools/dev/web_probe.mjs "<url>" <seconds> <out_dir>
// Needs: the build served on localhost (python tools/dev/serve_web.py). Uses its own throwaway Chrome profile.
import { spawn } from "node:child_process";
import { writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const url = process.argv[2] ?? "http://localhost:8060/?autostart&fps";
const seconds = Number(process.argv[3] ?? 40);
const out = process.argv[4] ?? ".";
mkdirSync(out, { recursive: true });
const chrome = "C:/Program Files/Google/Chrome/Application/chrome.exe";
const port = 9333;
const proc = spawn(chrome, ["--headless=new", `--remote-debugging-port=${port}`, `--user-data-dir=${join(out, "profile")}`, "--use-angle=d3d11",
  "--enable-gpu", "--ignore-gpu-blocklist", "--window-size=1280,720", "--autoplay-policy=no-user-gesture-required", "about:blank"], { stdio: "ignore" });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let ws;
for (let i = 0; i < 40; i++) {
  try {
    const list = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
    const page = list.find((t) => t.type === "page");
    if (page) { ws = new WebSocket(page.webSocketDebuggerUrl); break; }
  } catch {}
  await sleep(250);
}
await new Promise((r) => ws.addEventListener("open", r));
let id = 0;
let glErrors = 0;
const pending = new Map();
const send = (method, params = {}) => new Promise((res) => { const i = ++id; pending.set(i, res); ws.send(JSON.stringify({ id: i, method, params })); });
const t0 = Date.now();
ws.addEventListener("message", (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m.result); pending.delete(m.id); return; }
  if (m.method === "Runtime.consoleAPICalled") {
    const text = m.params.args.map((a) => a.value ?? a.description ?? "").join(" ");
    if (/WEBDIAG|ERROR|rror/.test(text)) console.log(`[${((Date.now() - t0) / 1000).toFixed(1)}s] ${text.slice(0, 300)}`);
  }
  if (m.method === "Log.entryAdded") { glErrors++; if (glErrors < 3) console.log(`[log] ${m.params.entry.text.slice(0, 200)}`); }
  if (m.method === "Runtime.exceptionThrown") console.log(`[exception] ${m.params.exceptionDetails.text} ${m.params.exceptionDetails.exception?.description?.slice(0, 200) ?? ""}`);
});
await send("Runtime.enable");
await send("Log.enable");
await send("Page.enable");
await send("Page.navigate", { url });
const shots = [Math.min(15, seconds), Math.min(28, seconds), seconds];
let shot = 0;
for (const at of shots) {
  await sleep(Math.max(0, at * 1000 - (Date.now() - t0)));
  const r = await send("Page.captureScreenshot", { format: "png" });
  writeFileSync(join(out, `web_${shot++}.png`), Buffer.from(r.data, "base64"));
  console.log(`[${((Date.now() - t0) / 1000).toFixed(1)}s] screenshot web_${shot - 1}.png`);
}
const fps = await send("Runtime.evaluate", { expression: "new Promise(r=>{let n=0;const t=performance.now();(function f(){n++;if(performance.now()-t<3000)requestAnimationFrame(f);else r(n/3)})()})", awaitPromise: true });
console.log(`page frames per second: ${fps.result?.value}   browser log entries (GL errors and warnings): ${glErrors}`);
ws.close();
proc.kill();
process.exit(0);
