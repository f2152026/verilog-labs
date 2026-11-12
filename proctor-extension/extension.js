// Exam Proctor extension (plain JavaScript, no dependencies).
//
// What it does
//  1. A thin pane in the secondary side bar asks for room/seat once, calibrates the
//     full-screen height (F11), then watches the pane height and tab visibility.
//  2. The STATUS BAR is the only indicator. It shows four counts and turns red as soon
//     as any is above 0 (or the pane is hidden / setup is not done):
//       full screen left (incl. pane hidden) and tab switches in this codespace session,
//       non-whitelisted files ever changed in the repo history, disallowed extensions
//       (+1 if AI features are switched on).
//     The two session counts are reset only from Firestore: set field resetAt
//     (timestamp) in the document <course>/<github user>.
//  3. Every event goes to Firestore <course>/<user>/events/<auto id> and to
//     .proctor/log.jsonl; the repo is committed and pushed after every build and
//     immediately when a non-whitelisted file changes.
'use strict';
const vscode = require('vscode');
const fs = require('fs');
const path = require('path');
const os = require('os');
const cp = require('child_process');

let CFG = null;
let ctx = null;
let root = null;                 // workspace folder path
let view = null;                 // WebviewView
let statusItem = null;
let ident = {};                  // user, repo, codespace, session
const C = { fsNow: false, paneHidden: true, tabHidden: false, badFiles: [], extras: [], ai: false };
const queueKey = 'proctor.queue';

// ---------------------------------------------------------------- utilities
function now() { return new Date().toISOString(); }

function sh(cmd, args, opts = {}) {
  return new Promise((resolve) => {
    cp.execFile(cmd, args, { cwd: root, maxBuffer: 1 << 22, ...opts }, (err, stdout, stderr) => {
      resolve({ ok: !err, out: (stdout || '').toString(), err: (stderr || '').toString() });
    });
  });
}

function globToRe(g) {
  let re = '';
  for (let i = 0; i < g.length; i++) {
    const c = g[i];
    if (c === '*' && g[i + 1] === '*') { re += '.*'; i++; if (g[i + 1] === '/') i++; }
    else if (c === '*') re += '[^/]*';
    else if (c === '?') re += '[^/]';
    else re += c.replace(/[.+^${}()|[\]\\]/g, '\\$&');
  }
  return new RegExp('^' + re + '$');
}
let allowedRes = [];
function fileAllowed(p) { return allowedRes.some((r) => r.test(p)); }

// ---------------------------------------------------------------- logging
function fsValue(v) {
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  return { stringValue: String(v ?? '') };
}

async function postFirestore(ev) {
  const fb = CFG.firebase;
  const url = CFG.testEndpoint
    ? CFG.testEndpoint
    : `https://firestore.googleapis.com/v1/projects/${fb.projectId}/databases/(default)/documents/` +
      `${encodeURIComponent(CFG.course)}/${encodeURIComponent(ident.user)}/events?key=${fb.apiKey}`;
  const fields = {};
  for (const [k, v] of Object.entries(ev)) fields[k] = fsValue(v);
  const r = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ fields }) });
  if (!r.ok) throw new Error('firestore ' + r.status + ' ' + (await r.text()).slice(0, 200));
}

let flushing = false;
async function flushQueue() {
  if (flushing) return;
  flushing = true;
  try {
    let q = ctx.globalState.get(queueKey, []);
    while (q.length) {
      try { await postFirestore(q[0]); } catch (e) { console.log('[proctor] ' + e.message); break; }
      q = q.slice(1);
      await ctx.globalState.update(queueKey, q);
    }
  } finally { flushing = false; }
}

function logEvent(type, detail = {}, isViolation = false) {
  const st = ctx.globalState;
  const ev = {
    type,
    detail: JSON.stringify(detail).slice(0, 1500),
    violation: isViolation,
    user: ident.user, repo: ident.repo, codespace: ident.codespace,
    exam: CFG.exam, session: ident.session,
    room: st.get('proctor.room', ''), seat: st.get('proctor.seat', ''),
    clientTime: now(),
  };
  try {
    fs.mkdirSync(path.join(root, '.proctor'), { recursive: true });
    fs.appendFileSync(path.join(root, '.proctor', 'log.jsonl'), JSON.stringify(ev) + '\n');
  } catch (e) { /* ignore */ }
  const q = st.get(queueKey, []);
  q.push(ev);
  st.update(queueKey, q).then(flushQueue);
}

// ---------------------------------------------------------------- status bar
function counts() {
  const st = ctx.globalState;
  return { fs: st.get('proctor.fsCount', 0), tab: st.get('proctor.tabCount', 0),
           files: C.badFiles.length, ext: C.extras.length + (C.ai ? 1 : 0) };
}

async function bump(key) {
  await ctx.globalState.update(key, ctx.globalState.get(key, 0) + 1);
  render();
}

function render() {
  if (!statusItem) return;
  const calibrated = ctx.globalState.get('proctor.calibrated', false);
  const c = counts();
  const ok = calibrated && !c.fs && !c.tab && !c.files && !c.ext && !C.fsNow && !C.tabHidden && !C.paneHidden;
  const tally = `Full screen left ${c.fs} · Tab switches ${c.tab} · Files ${c.files} · Extensions ${c.ext}`;
  let text = calibrated ? (ok ? '$(pass-filled) EXAM OK   ' : '$(error) EXAM   ') + tally
                        : '$(warning) EXAM SETUP: enter room/seat in the Exam pane, then press F11';
  if (C.paneHidden) text += ' · EXAM PANE HIDDEN';
  statusItem.text = text;
  const tip = [];
  if (C.badFiles.length) tip.push('Files changed that are not answer files:\n  ' + C.badFiles.join('\n  '));
  if (C.extras.length) tip.push('Extensions not allowed:\n  ' + C.extras.join('\n  '));
  if (C.ai) tip.push('AI features are switched on');
  statusItem.tooltip = tip.join('\n\n') || 'Exam monitor';
  const colors = ok
    ? { 'statusBar.background': '#1e8e3e', 'statusBar.foreground': '#ffffff', 'statusBar.noFolderBackground': '#1e8e3e' }
    : { 'statusBar.background': '#c5221f', 'statusBar.foreground': '#ffffff', 'statusBar.noFolderBackground': '#c5221f' };
  const cc = vscode.workspace.getConfiguration('workbench');
  const cur = cc.get('colorCustomizations') || {};
  if (cur['statusBar.background'] !== colors['statusBar.background']) {
    cc.update('colorCustomizations', { ...cur, ...colors }, vscode.ConfigurationTarget.Global).then(undefined, () => {});
  }
}

function post(msg) { if (view) view.webview.postMessage(msg).then(undefined, () => {}); }

// ---------------------------------------------------------------- webview
function stripHtml(webview) {
  const nonce = Math.random().toString(36).slice(2);
  const file = path.join(ctx.extensionPath, 'media', 'strip.html');
  return fs.readFileSync(file, 'utf8')
    .replace(/__NONCE__/g, nonce)
    .replace(/__CSP__/g, webview.cspSource);
}

class StripProvider {
  resolveWebviewView(v) {
    view = v;
    v.webview.options = { enableScripts: true };
    v.webview.html = stripHtml(v.webview);
    v.webview.onDidReceiveMessage(onWebviewMessage);
    const hidden = (why) => {
      if (C.paneHidden) return;
      C.paneHidden = true;
      logEvent(why, {}, true);
      if (ctx.globalState.get('proctor.calibrated', false)) bump('proctor.fsCount'); else render();
    };
    v.onDidChangeVisibility(() => {
      if (v.visible) { C.paneHidden = false; logEvent('pane_visible'); sendInit(); render(); }
      else hidden('pane_hidden');
    });
    v.onDidDispose(() => { view = null; hidden('pane_closed'); });
    C.paneHidden = false;
    render();
  }
}

function sendInit() {
  const st = ctx.globalState;
  post({
    type: 'init',
    user: ident.user,
    room: st.get('proctor.room', ''), seat: st.get('proctor.seat', ''),
    calibrated: st.get('proctor.calibrated', false),
    hMax: st.get('proctor.hMax', 0),
  });
}

async function onWebviewMessage(m) {
  const st = ctx.globalState;
  switch (m.type) {
    case 'ready': sendInit(); break;
    case 'setup':
      await st.update('proctor.room', String(m.room).slice(0, 40));
      await st.update('proctor.seat', String(m.seat).slice(0, 40));
      logEvent('setup', { room: m.room, seat: m.seat, screen: m.screen });
      break;
    case 'calibrated':
      await st.update('proctor.hMax', m.hMax);
      await st.update('proctor.calibrated', true);
      logEvent('calibrated', { h0: m.h0, hMax: m.hMax, dpr: m.dpr, screen: m.screen });
      render();
      break;
    case 'fullscreen':
      if (m.ok) { C.fsNow = false; logEvent('fullscreen_restored', { h: m.h, hMax: m.hMax, awayMs: m.awayMs }); render(); }
      else { C.fsNow = true; logEvent('fullscreen_left', { h: m.h, hMax: m.hMax }, true); await bump('proctor.fsCount'); }
      break;
    case 'visibility':
      if (m.visible) { C.tabHidden = false; logEvent('tab_visible', { awayMs: m.awayMs }); render(); }
      else { C.tabHidden = true; logEvent('tab_hidden', {}, true); await bump('proctor.tabCount'); }
      break;
    case 'zoom':
      logEvent('zoom_changed', { dpr: m.dpr }, true);
      break;
    case 'openSheet':
      openSheet();
      break;
  }
}

function openSheet() {
  const p = path.join(root, CFG.syntaxSheet);
  if (fs.existsSync(p)) vscode.commands.executeCommand('markdown.showPreview', vscode.Uri.file(p));
}

// ---------------------------------------------------------------- extension audit
let reportedExt = new Set();
function auditExtensions(first) {
  const allowed = new Set(CFG.allowedExtensions.map((s) => s.toLowerCase()));
  const extra = [];
  const all = [];
  for (const e of vscode.extensions.all) {
    if (e.packageJSON && e.packageJSON.isBuiltin) continue;
    const id = e.id.toLowerCase();
    all.push(id);
    if (!allowed.has(id)) extra.push(id);
  }
  if (first) logEvent('extensions_snapshot', { installed: all });
  for (const id of extra) {
    if (!reportedExt.has(id)) { reportedExt.add(id); logEvent('extension_not_allowed', { id }, true); }
  }
  C.extras = extra;
  render();
}

function auditAI(first) {
  const disabled = vscode.workspace.getConfiguration('chat').get('disableAIFeatures', false);
  if (!disabled) {
    if (first || !auditAI.flagged) logEvent('ai_features_enabled', {}, true);
    auditAI.flagged = true;
    C.ai = true; render();
  } else { auditAI.flagged = false; C.ai = false; render(); }
}

// ---------------------------------------------------------------- git: whitelist + autocommit
let gitBusy = Promise.resolve();
function gitQueue(fn) { gitBusy = gitBusy.then(fn, fn); return gitBusy; }

async function commitAndPush(message) {
  return gitQueue(async () => {
    await sh('git', ['add', '-A']);
    const c = await sh('git', ['-c', 'user.name=' + ident.user, '-c', 'user.email=' + ident.user + '@users.noreply.github.com',
      'commit', '-q', '-m', message]);
    const p = await sh('git', ['push', '-q', 'origin', 'HEAD']);
    if (!p.ok) logEvent('push_failed', { message, err: p.err.slice(0, 300) });
    return c.ok;
  });
}

let baseCommit = null;
// A path counts as changed when its content (as git would store it) differs from the
// baseline: the state when the extension first ran in this codespace. Files that codespace
// setup already touched (line endings, chmod) are part of the baseline, and mode-only
// changes are ignored. Every commit since the baseline is checked too, so a change that
// was committed and later undone still counts.
const DEL = 'DELETED';
let baseline = {};                 // path -> blob at first run, for paths dirty at first run
const baseBlobCache = new Map();
async function hashFile(p) {
  if (!fs.existsSync(path.join(root, p))) return DEL;
  const h = await sh('git', ['hash-object', '--', p]);
  return h.ok ? h.out.trim() : DEL;
}
async function baseBlob(p) {
  if (p in baseline) return baseline[p];
  if (baseBlobCache.has(p)) return baseBlobCache.get(p);
  const r = await sh('git', ['rev-parse', '--verify', '-q', baseCommit + ':' + p]);
  const v = r.ok ? r.out.trim() : DEL;
  baseBlobCache.set(p, v);
  return v;
}
async function dirtyPaths() {
  const s = await sh('git', ['-c', 'core.fileMode=false', 'status', '--porcelain', '-uall', '-z']);
  const out = new Set();
  const parts = s.out.split('\0');
  for (let i = 0; i < parts.length; i++) {
    const e = parts[i];
    if (!e) continue;
    out.add(e.slice(3));
    if (e[0] === 'R' || e[0] === 'C') { out.add(parts[i + 1]); i++; }
  }
  return [...out];
}
async function makeBaseline() {
  const b = {};
  for (const p of await dirtyPaths()) b[p] = await hashFile(p);
  return b;
}
async function touchedPaths() {
  const out = new Set();
  for (const p of await dirtyPaths()) {
    if (fileAllowed(p)) continue;
    if ((await hashFile(p)) !== (await baseBlob(p))) out.add(p);
  }
  if (baseCommit) {
    const d = await sh('git', ['log', '--format=', '--raw', '--no-renames', '--no-abbrev', baseCommit + '..HEAD']);
    for (const line of d.out.split('\n')) {
      const m = line.match(/^:\d+ \d+ [0-9a-f]+ ([0-9a-f]+) \w+\t(.*)$/);
      if (!m || fileAllowed(m[2]) || out.has(m[2])) continue;
      const blob = /^0+$/.test(m[1]) ? DEL : m[1];
      if (blob !== (await baseBlob(m[2]))) out.add(m[2]);
    }
  }
  return [...out];
}

async function checkFiles() {
  const known = new Set(ctx.globalState.get('proctor.badFiles', []));
  const fresh = (await touchedPaths()).filter((f) => !fileAllowed(f) && !known.has(f));
  if (fresh.length) {
    fresh.forEach((f) => known.add(f));
    await ctx.globalState.update('proctor.badFiles', [...known]);
    logEvent('file_not_allowed', { files: fresh.slice(0, 50) }, true);
  }
  C.badFiles = [...known].sort();
  render();
  if (fresh.length) await commitAndPush('proctor: non-whitelisted change: ' + fresh.slice(0, 5).join(', '));
}

// ---------------------------------------------------------------- reset from Firestore
async function checkReset() {
  const fb = CFG.firebase;
  const url = CFG.testResetEndpoint ||
    `https://firestore.googleapis.com/v1/projects/${fb.projectId}/databases/(default)/documents/` +
    `${encodeURIComponent(CFG.course)}/${encodeURIComponent(ident.user)}?key=${fb.apiKey}`;
  let doc;
  try {
    const r = await fetch(url);
    if (!r.ok) return;                       // 404: no reset document for this student
    doc = await r.json();
  } catch { return; }
  const f = (doc.fields || {}).resetAt;
  if (!f) return;
  const ms = Date.parse(f.timestampValue || f.stringValue || '') || Number(f.integerValue || 0);
  const st = ctx.globalState;
  if (ms && ms > st.get('proctor.lastReset', 0)) {
    const before = counts();
    await st.update('proctor.lastReset', ms);
    await st.update('proctor.fsCount', 0);
    await st.update('proctor.tabCount', 0);
    logEvent('reset_applied', { resetAt: new Date(ms).toISOString(), fsBefore: before.fs, tabBefore: before.tab });
    render();
  }
}

let lastBuild = 0;
function newestBuildMtime() {
  let newest = 0;
  const walk = (d, depth) => {
    let ents = [];
    try { ents = fs.readdirSync(d, { withFileTypes: true }); } catch { return; }
    for (const e of ents) {
      const p = path.join(d, e.name);
      if (e.isDirectory() && depth < 4) walk(p, depth + 1);
      else if (e.isFile() && e.name.endsWith('.sim')) {
        try { newest = Math.max(newest, fs.statSync(p).mtimeMs); } catch { /* gone */ }
      }
    }
  };
  for (const b of CFG.buildOutputs) walk(path.join(root, b), 0);
  return newest;
}

async function checkBuild() {
  const m = newestBuildMtime();
  if (m > lastBuild) {
    const first = lastBuild === 0 && !checkBuild.started;
    lastBuild = m;
    if (!first) {
      logEvent('build', {});
      await commitAndPush('proctor: autocommit after build ' + now());
    }
  }
  checkBuild.started = true;
}

// ---------------------------------------------------------------- activate
async function activate(context) {
  ctx = context;
  CFG = JSON.parse(fs.readFileSync(path.join(context.extensionPath, 'proctor.config.json'), 'utf8'));
  allowedRes = CFG.allowedFiles.map(globToRe);
  const folder = vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders[0];
  if (!folder) return;
  root = folder.uri.fsPath;

  const remote = await sh('git', ['config', '--get', 'remote.origin.url']);
  ident = {
    user: process.env.GITHUB_USER || os.userInfo().username,
    repo: process.env.GITHUB_REPOSITORY || remote.out.trim().replace(/^.*github\.com[/:]/, '').replace(/\.git$/, ''),
    codespace: process.env.CODESPACE_NAME || os.hostname(),
    session: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
  };
  // Base for "what changed": HEAD when the extension first ran in this codespace
  // (i.e. the starter state), kept across reloads.
  baseCommit = context.globalState.get('proctor.base', null);
  baseline = context.globalState.get('proctor.baseline', {});
  if (!baseCommit) {
    const b = await sh('git', ['rev-parse', 'HEAD']);
    if (b.ok) {
      baseCommit = b.out.trim();
      baseline = await makeBaseline();
      await context.globalState.update('proctor.base', baseCommit);
      await context.globalState.update('proctor.baseline', baseline);
      logEvent('baseline', { commit: baseCommit, dirtyAtStart: Object.keys(baseline) });
    }
  }

  statusItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 1000);
  statusItem.command = 'proctor.show';
  statusItem.show();
  context.subscriptions.push(statusItem);

  context.subscriptions.push(
    vscode.window.registerWebviewViewProvider('proctor.strip', new StripProvider(), { webviewOptions: { retainContextWhenHidden: true } }),
    vscode.commands.registerCommand('proctor.show', () => vscode.commands.executeCommand('proctor.strip.focus')),
    vscode.commands.registerCommand('proctor.openSheet', openSheet),
    vscode.extensions.onDidChange(() => auditExtensions(false)),
    vscode.workspace.onDidChangeConfiguration((e) => { if (e.affectsConfiguration('chat')) auditAI(false); }),
  );

  logEvent('session_start', { vscode: vscode.version, platform: process.platform });
  auditExtensions(true);
  auditAI(true);
  render();

  // open the strip (secondary side bar) and the syntax sheet
  setTimeout(() => {
    vscode.commands.executeCommand('workbench.action.focusAuxiliaryBar').then(undefined, () => {});
    vscode.commands.executeCommand('proctor.strip.focus').then(undefined, () => {});
  }, 1500);

  const poll = async () => {
    try { await checkBuild(); await checkFiles(); } catch (e) { console.log('[proctor] ' + e.message); }
    flushQueue();
  };
  const t = setInterval(poll, (CFG.gitPollSeconds || 5) * 1000);
  const t2 = setInterval(() => auditExtensions(false), 30000);
  const t3 = setInterval(checkReset, (CFG.resetPollSeconds || 20) * 1000);
  context.subscriptions.push({ dispose: () => { clearInterval(t); clearInterval(t2); clearInterval(t3); } });
  checkReset();
  poll();
}

function deactivate() {
  if (ctx) logEvent('session_end', {});
}

module.exports = { activate, deactivate, _test: { onWebviewMessage: (m) => onWebviewMessage(m), counts: () => counts(), status: () => statusItem && statusItem.text } };
