// Exam Proctor extension (plain JavaScript, no dependencies).
//
// What it does
//  1. A thin strip in the secondary side bar. After a one-time room/seat prompt and
//     a full-screen calibration, it is GREEN while the browser stays full screen and
//     the tab is visible, RED otherwise. The status bar mirrors the colour.
//  2. Logs every violation (left full screen, tab hidden, pane hidden, zoom change,
//     extra extension, AI features re-enabled, change to a non-whitelisted file) to
//     Firestore: <course>/<github user>/events/<auto id>, and to .proctor/log.jsonl.
//  3. Commits and pushes the repository after every build (new simulation binary
//     under artefacts/) and immediately when a non-whitelisted file changes.
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
let problems = new Map();        // reason key -> text   (anything here => RED)
let violations = 0;
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
  if (isViolation) violations++;
  try {
    fs.mkdirSync(path.join(root, '.proctor'), { recursive: true });
    fs.appendFileSync(path.join(root, '.proctor', 'log.jsonl'), JSON.stringify(ev) + '\n');
  } catch (e) { /* ignore */ }
  const q = st.get(queueKey, []);
  q.push(ev);
  st.update(queueKey, q).then(flushQueue);
}

// ---------------------------------------------------------------- red / green
function setProblem(key, text) {
  if (text) problems.set(key, text); else problems.delete(key);
  render();
}

function render() {
  const ok = problems.size === 0 && ctx.globalState.get('proctor.calibrated', false);
  const msg = [...problems.values()].join(' | ');
  if (statusItem) {
    statusItem.text = ok ? '$(pass-filled) EXAM OK' : '$(error) EXAM: ' + (msg || 'setup needed');
  }
  const colors = ok
    ? { 'statusBar.background': '#1e8e3e', 'statusBar.foreground': '#ffffff' }
    : { 'statusBar.background': '#c5221f', 'statusBar.foreground': '#ffffff' };
  const cc = vscode.workspace.getConfiguration('workbench');
  const cur = cc.get('colorCustomizations') || {};
  if (cur['statusBar.background'] !== colors['statusBar.background']) {
    cc.update('colorCustomizations', { ...cur, ...colors }, vscode.ConfigurationTarget.Global).then(undefined, () => {});
  }
  post({ type: 'host', problems: [...problems.values()], violations });
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
    v.onDidChangeVisibility(() => {
      if (v.visible) { setProblem('pane', null); logEvent('pane_visible'); sendInit(); }
      else { setProblem('pane', 'monitor pane hidden'); logEvent('pane_hidden', {}, true); }
    });
    v.onDidDispose(() => {
      view = null;
      setProblem('pane', 'monitor pane closed');
      logEvent('pane_closed', {}, true);
    });
    setProblem('pane', null);
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
    problems: [...problems.values()], violations,
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
      if (m.ok) { setProblem('fs', null); logEvent('fullscreen_restored', { h: m.h, hMax: m.hMax, awayMs: m.awayMs }); }
      else { setProblem('fs', 'not full screen'); logEvent('fullscreen_left', { h: m.h, hMax: m.hMax }, true); }
      break;
    case 'visibility':
      if (m.visible) { setProblem('tab', null); logEvent('tab_visible', { awayMs: m.awayMs }); }
      else { setProblem('tab', 'tab not visible'); logEvent('tab_hidden', {}, true); }
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
  setProblem('ext', extra.length ? 'remove extension: ' + extra.join(', ') : null);
}

function auditAI(first) {
  const disabled = vscode.workspace.getConfiguration('chat').get('disableAIFeatures', false);
  if (!disabled) {
    if (first || !auditAI.flagged) logEvent('ai_features_enabled', {}, true);
    auditAI.flagged = true;
    setProblem('ai', 'AI features enabled');
  } else { auditAI.flagged = false; setProblem('ai', null); }
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
let reportedFiles = new Set();
async function changedPaths() {
  const s = await sh('git', ['status', '--porcelain', '-uall', '-z']);
  const out = new Set();
  const parts = s.out.split('\0');
  for (let i = 0; i < parts.length; i++) {
    const e = parts[i];
    if (!e) continue;
    const code = e.slice(0, 2);
    out.add(e.slice(3));
    if (code[0] === 'R' || code[0] === 'C') { out.add(parts[i + 1]); i++; }   // rename: both names
  }
  if (baseCommit) {
    const d = await sh('git', ['diff', '--name-only', '-z', baseCommit, 'HEAD']);
    for (const f of d.out.split('\0')) if (f) out.add(f);
  }
  return [...out];
}

async function checkFiles() {
  const bad = (await changedPaths()).filter((f) => !fileAllowed(f) && !reportedFiles.has(f));
  if (!bad.length) return;
  bad.forEach((f) => reportedFiles.add(f));
  logEvent('file_not_allowed', { files: bad.slice(0, 50) }, true);
  await commitAndPush('proctor: non-whitelisted change: ' + bad.slice(0, 5).join(', '));
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
  if (!baseCommit) {
    const b = await sh('git', ['rev-parse', 'HEAD']);
    if (b.ok) { baseCommit = b.out.trim(); await context.globalState.update('proctor.base', baseCommit); }
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
  setProblem('pane', 'monitor pane not open');
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
  context.subscriptions.push({ dispose: () => { clearInterval(t); clearInterval(t2); } });
  poll();
}

function deactivate() {
  if (ctx) logEvent('session_end', {});
}

module.exports = { activate, deactivate };
