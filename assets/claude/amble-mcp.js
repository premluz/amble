// Amble's Claude extension server. Claude Desktop starts this with its
// built-in Node and talks MCP over stdin/stdout (one JSON-RPC message per
// line). It is only a pipe: every message is forwarded to the Amble app's
// local endpoint, which does all the work and holds all the data.
//
// If Amble is not running, it is started in the background (`open -g -j`)
// and the message is retried for a few seconds.
//
// Settings come from the extension manifest's env, written by Amble when
// the person pressed "Connect to Claude": AMBLE_PORT, AMBLE_SECRET and
// AMBLE_BUNDLE_ID. Uses only Node's built-in modules.
'use strict';

const http = require('http');
const readline = require('readline');
const { execFile } = require('child_process');

const PORT = Number(process.env.AMBLE_PORT);
const SECRET = process.env.AMBLE_SECRET || '';
const BUNDLE_ID = process.env.AMBLE_BUNDLE_ID || '';
const PATH = '/mcp';
// Overridable only so tests don't wait the full ten seconds.
const LAUNCH_WAIT_MS = Number(process.env.AMBLE_LAUNCH_WAIT_MS) || 10000;
const RETRY_MS = 500;
const NOT_RUNNING =
  "Amble isn't running and couldn't be opened. Open Amble and try again.";

// Legacy clients negotiate a version once, in `initialize`; later requests
// carry it in the MCP-Protocol-Version header.
let negotiatedVersion = null;
let launched = false;

function log(message) {
  process.stderr.write(`[amble] ${message}\n`);
}

function headerValue(value) {
  return /^[\x20-\x7e]*$/.test(value) && !/^\s|\s$/.test(value)
    ? value
    : `=?base64?${Buffer.from(value, 'utf8').toString('base64')}?=`;
}

function headersFor(message, body) {
  const headers = {
    'Content-Type': 'application/json',
    Accept: 'application/json, text/event-stream',
    Authorization: `Bearer ${SECRET}`,
    'Content-Length': Buffer.byteLength(body),
  };
  const params = message.params || {};
  const meta = params._meta || {};
  const version =
    meta['io.modelcontextprotocol/protocolVersion'] || negotiatedVersion;
  if (version) headers['MCP-Protocol-Version'] = version;
  if (typeof message.method === 'string') {
    headers['Mcp-Method'] = message.method;
  }
  if (message.method === 'tools/call' && typeof params.name === 'string') {
    headers['Mcp-Name'] = headerValue(params.name);
  }
  return headers;
}

function post(message) {
  const body = JSON.stringify(message);
  return new Promise((resolve, reject) => {
    const request = http.request(
      {
        host: '127.0.0.1',
        port: PORT,
        path: PATH,
        method: 'POST',
        headers: headersFor(message, body),
      },
      (response) => {
        let data = '';
        response.setEncoding('utf8');
        response.on('data', (chunk) => (data += chunk));
        response.on('end', () => resolve({ status: response.statusCode, data }));
      },
    );
    request.on('error', reject);
    request.end(body);
  });
}

function openAmble() {
  if (launched || !BUNDLE_ID) return;
  launched = true;
  log('starting Amble in the background');
  execFile('open', ['-g', '-j', '-b', BUNDLE_ID], (error) => {
    if (error) log(`could not start Amble: ${error.message}`);
  });
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function forward(message) {
  const deadline = Date.now() + LAUNCH_WAIT_MS;
  for (;;) {
    try {
      return await post(message);
    } catch (error) {
      if (error.code !== 'ECONNREFUSED' || Date.now() > deadline) throw error;
      openAmble();
      await sleep(RETRY_MS);
    }
  }
}

function reply(object) {
  process.stdout.write(`${JSON.stringify(object)}\n`);
}

function replyError(id, message) {
  if (id === undefined) return;
  reply({ jsonrpc: '2.0', id, error: { code: -32603, message } });
}

async function handle(line) {
  if (!line.trim()) return;
  let message;
  try {
    message = JSON.parse(line);
  } catch (error) {
    reply({ jsonrpc: '2.0', id: null, error: { code: -32700, message: 'Parse error' } });
    return;
  }
  let response;
  try {
    response = await forward(message);
  } catch (error) {
    log(`request failed: ${error.message}`);
    replyError(message.id, NOT_RUNNING);
    return;
  }
  if (response.status === 202) return;
  if (response.status === 401) {
    replyError(
      message.id,
      'Amble refused this connection. Reconnect Claude in Amble: Settings › Claude.',
    );
    return;
  }
  let parsed;
  try {
    parsed = JSON.parse(response.data);
  } catch (error) {
    replyError(message.id, `Amble answered with HTTP ${response.status}.`);
    return;
  }
  if (message.method === 'initialize' && parsed.result) {
    negotiatedVersion = parsed.result.protocolVersion || null;
  }
  reply(parsed);
}

// Messages are handled one at a time, in order.
let queue = Promise.resolve();
readline
  .createInterface({ input: process.stdin })
  .on('line', (line) => {
    queue = queue.then(() => handle(line));
  })
  .on('close', () => queue.then(() => process.exit(0)));

if (!PORT || !SECRET) log('AMBLE_PORT or AMBLE_SECRET is missing');
