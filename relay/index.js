const crypto = require('crypto');
const functions = require('@google-cloud/functions-framework');
const { Storage } = require('@google-cloud/storage');

if (!process.env.TOKEN) throw new Error('TOKEN env var is required');
if (!process.env.BUCKET) throw new Error('BUCKET env var is required');

const bucket = new Storage().bucket(process.env.BUCKET);
const sha = (s) => crypto.createHash('sha256').update(s).digest();
const expected = sha(process.env.TOKEN);

// One minimal headless Claude Code turn; the subscription limits ride along on
// its rate_limit_event. utilization is a fraction (0.03 = 3%).
async function readLimits() {
  const { query } = await import('@anthropic-ai/claude-agent-sdk');
  let windows;
  for await (const m of query({
    prompt: 'ok',
    options: {
      model: 'haiku',
      systemPrompt: 'Reply ok.',
      tools: [],
      settingSources: [],
      strictMcpConfig: true,
      persistSession: false,
      maxTurns: 1,
      // Claude Code writes its config under HOME; only /tmp is reliably writable here.
      env: { ...process.env, HOME: '/tmp' },
    },
  })) {
    if (m.type === 'rate_limit_event') windows = m.rate_limit_info.unifiedWindows;
  }
  const out = {};
  if (windows?.five_hour?.utilization != null) {
    out.h5 = Math.round(windows.five_hour.utilization * 100);
    out.r5 = windows.five_hour.resetsAt;
  }
  if (windows?.seven_day?.utilization != null) {
    out.d7 = Math.round(windows.seven_day.utilization * 100);
    out.r7 = windows.seven_day.resetsAt;
  }
  if (Object.keys(out).length === 0) throw new Error('no rate_limit_event windows in Claude output');
  return out;
}

functions.http('relay', async (req, res) => {
  if (req.path !== '/usage' && req.path !== '/poll') return res.status(404).end();

  // Header only: Cloud Run access logs record full URLs, so a query param would persist the token.
  const token = (req.get('authorization') || '').replace(/^Bearer /i, '').toLowerCase();
  const hash = sha(token);
  if (!crypto.timingSafeEqual(hash, expected)) return res.status(401).end();

  // Keyed by token hash so adding users later only changes the check above.
  const file = bucket.file(`usage/${hash.toString('hex')}.json`);

  // Called by Cloud Scheduler.
  if (req.path === '/poll' && req.method === 'POST') {
    const out = await readLimits();
    out.ts = Math.floor(Date.now() / 1000);
    await file.save(JSON.stringify(out), { contentType: 'application/json', resumable: false });
    return res.status(204).end();
  }

  if (req.path === '/usage' && req.method === 'GET') {
    res.set('Cache-Control', 'no-store');
    let body;
    try {
      [body] = await file.download();
    } catch (err) {
      if (err.code === 404) return res.status(204).end(); // nothing polled yet
      throw err;
    }
    return res.type('json').send(body.toString());
  }

  res.status(405).end();
});
