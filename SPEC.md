# Token Glance — spec

A glance on my Garmin Venu 4 showing how much of my Claude subscription limits
I have used. Personal, sideloaded build first; store release and other
providers are later and must not add code now.

Supersedes `../garmin-ext/claude-glance/plan.md`. That project is reference
material only: about 4,000 lines for a pairing relay, a timeline protocol and a
chart, with no data source ever built. This version targets roughly 300 lines
and starts from the data source.

## Decisions

| Question | Decision |
|---|---|
| Metric | Subscription limit usage: 5-hour and 7-day percentage plus reset time. No cost, no token counts. |
| Audience | Me. Keep two seams for a store release (below), build nothing else for it. |
| Backend | One small function in the existing `token-glance` GCP project. |
| Tap-through | One static detail page. Timeline chart is a later feature. |

## How it works

```
Cloud Scheduler ──POST /poll──▶ relay (1 function, 1 doc) ──GET /usage──▶ watch
 (every 10 min)        │                                        (every 5 min)
                       └─ one minimal Claude Code turn via the Agent SDK
```

The limit numbers are account-wide, so one poller covers the desktop app, the
terminal and claude.ai. Nothing runs on the Mac.

### Payload

The same JSON travels both hops and is all the watch ever stores.

```json
{"h5":42,"r5":1774209600,"d7":78,"r7":1774600000,"ts":1774200000}
```

- `h5`, `d7`: integer percent used, 0-100. Either may be absent.
- `r5`, `r7`: reset time, unix seconds.
- `ts`: set by the relay on write.

## 1. Poller: inside the relay

There is no separate sender. Cloud Scheduler job `usage-poll` (europe-west1)
POSTs to the relay's `/poll` every 10 minutes, and the relay reads the limits
itself:

1. Run one stripped-down Claude Code turn through the Node Agent SDK
   (`@anthropic-ai/claude-agent-sdk`): Haiku, one-line system prompt, no
   tools, no settings, no session persistence. It authenticates with the
   long-lived token from `claude setup-token`, supplied as
   `CLAUDE_CODE_OAUTH_TOKEN` from Secret Manager secret `claude-token`.
2. Take the `rate_limit_event` message. `rate_limit_info.unifiedWindows` holds
   `five_hour` and `seven_day`, each with `utilization` (a fraction, 0.03 =
   3%) and `resetsAt` (unix seconds). `unifiedWindows` is not in the SDK's
   published types.
3. Write `{h5, r5, d7, r7, ts}` to the document. If the event is missing the
   request fails with a 500 and nothing is written.

Measured: about 7 seconds per poll and under 1,000 Haiku tokens, so roughly
140k Haiku tokens a day against my own limit.

The Claude token is valid for one year and can be revoked at
claude.ai/settings/claude-code. It lives in Secret Manager and in
`~/.claude/token-glance/env` on the Mac (mode 600), nowhere else.

## 2. Relay: `relay/index.js`

One Cloud Functions gen2 HTTP function, no framework. 1 GiB memory, because
the Agent SDK starts the Claude Code binary.

| Request | Behaviour |
|---|---|
| `POST /poll` | Check bearer token. Read the limits (section 1), add `ts`, write to Firestore doc `usage/<sha256(token)>`. |
| `GET /usage` | Check bearer token. Return the doc, or `204` if none. `Cache-Control: no-store`. |

- Auth is `Authorization: Bearer <token>`, compared against a single `TOKEN`
  env var. Never a query parameter: Cloud Run access logs record full URLs.
  The scheduler job sends the same header.
- The token is 26 characters of `[a-z2-7]`, generated locally. That alphabet is
  the only one the Garmin Connect settings keyboard can type.
- Uses the existing named Firestore database `token-glance`.
- Deploy with `relay/deploy.sh`, which pins the personal GCP account and
  project and hides gcloud output that would echo the token.

The old `watch-glance-relay` service and its data should be deleted once this
one works. The old dev token was written to access logs and must not be reused.

## 3. Watch app: `watch/`

Monkey C, type `watch-app`, products `venu441mm`, `venu445mm` and
`instinct3solar45mm`, permissions `Communications` and `Background`.

The Instinct 3 Solar is 1-bit, 176x176, with a round subscreen over the top
right. Code that differs there is annotated `(:mono)`, the rest `(:color)`;
`monkey.jungle` excludes one of the two per device.

| File | Job |
|---|---|
| `App.mc` | Registers the 5-minute temporal event, returns the views, saves background data to `Storage["snap"]`. |
| `Fetch.mc` | Background delegate. One `makeWebRequest`, one `Background.exit()` with the payload, on every path. |
| `GlanceView.mc` | Draws the glance from `Storage["snap"]`. |
| `GlanceViewMono.mc` | The same glance for the Instinct, kept left of the subscreen. |
| `DetailView.mc` | Draws the detail page from `Storage["snap"]`. |

Settings: `relayHost` and `token`, as app properties editable in Garmin
Connect. `resources/properties/properties.xml` is gitignored and holds my real
values so I never type them; `properties.example.xml` is committed.

One build variant. No mock data: the simulator fetches from the real relay,
which I can seed with `curl`.

### Glance

Native Venu glances are a card with an icon in a round panel on the left,
then a title, one large value and at most one thin graphic, in white with a
single accent colour. This follows that. The card and its gradient are drawn
by the system: the glance must not clear or fill its background. The left
panel shows the launcher icon, so that is a one-colour glyph (an orange
starburst), not a chart.

```
 Claude                    7d 78%
 42%   2h 10m
 ━━━━━━━━━━━━│───────────────────     5h bar, │ = pace
 ━━━━━━━━━━━━━━━━━━━━━━━━│───────     7d bar, thinner
```

- **Title row:** `Claude` in the glance font, white like native titles.
  Weekly percentage right aligned, grey.
- **Value row:** 5-hour percentage in the glance number font, white. Next to
  it, time until the 5-hour reset, grey.
- **Bars:** 5-hour bar, then a thinner 7-day bar. Fill is Claude orange
  (`0xD97757`), turning red at 90 or above. Track is dark grey. The fill has a
  subtle gradient like native glance bars: full colour at the start, lightening
  toward the tip.
- **Pace tick:** a small white tick on each bar at the fraction of the window
  that has elapsed (`1 - (reset - now) / window`). Fill past the tick means I
  am burning faster than the window allows. This is the one addition over the
  old glance and the main reason to look at it.

Time handling happens at draw time on the watch, so the glance stays right
without fresh data:

- Countdowns are computed from `r5` / `r7` and the watch clock.
- Once a reset time has passed, that window shows 0% until new data arrives.
- No dimming for age. The poller runs around the clock, so data is at most
  about 15 minutes old unless the phone is out of reach.

Other states, one line of grey text each: `Set up in Garmin Connect` (no token
or host) and `Waiting for data` (nothing fetched yet, or `204`).

### Detail page

Static, no input handling beyond the default back behaviour.

```
        Claude
   5 hours        42%
   ━━━━━━━│────────────
   resets in 2h 10m

   7 days         78%
   ━━━━━━━━━━━━━│──────
   resets Thu 14:00

     updated 3m ago
```

## Seams kept for later

Only these. Each costs nothing now.

- **Store release:** token and host are settings, not constants; the relay
  keys its document by token hash, so many users is a change to the auth check
  only.
- **Timeline chart:** not prepared for. When wanted, the first thing to decide
  is whether the relay keeps history or the watch samples for itself.
- **Other providers:** not prepared for.

## Build order

Each step ends in something I can see working.

1. **Prove the data.** Done, see below.
2. **Relay.** Deploy, then PUT and GET with `curl`.
3. **Poller.** Create the scheduler job, watch the relay doc change.
4. **Glance.** Simulator first, both sizes, then sideload to the watch.
5. **Detail page.**
6. **Clean up** the old relay service and Firestore data.

## How the data source was chosen (2026-11-21)

- A statusline script only runs in the terminal CLI, not in the desktop app,
  which is where I mostly work. Rejected.
- Nothing on disk carries limit data, and hooks do not receive it.
- The account usage endpoint rejects the `setup-token` token: `403`, scope
  `user:profile` required. A direct Messages API call with it returns `429`.
- A headless Claude Code call with that token emits a `rate_limit_event` with
  both windows. Verified: it matched the desktop app's usage card. Chosen.
- First built as a launchd script on the Mac, then moved into the relay so it
  runs with the Mac off.

## Not yet verified

- `rate_limit_event` is not a documented contract. If a Claude Code update
  drops it, `/poll` returns 500 and the watch shows old data.
- `Graphics.FONT_GLANCE` and `FONT_GLANCE_NUMBER` exist for these devices.
  Check the SDK docs before using them.
- Battery cost of a 5-minute fetch. If it is noticeable, raise the interval;
  it is one constant.

## Lessons carried over from the old build

- Check every Monkey C API against the local SDK docs
  (`~/Library/Application Support/Garmin/ConnectIQ/Sdks/*/doc/`). Invented
  APIs were the main time sink. Build with `-l 3`.
- Foreground, glance and background are three separate binaries. Code needs
  `(:glance)` / `(:background)` annotations, and the app class needs typecheck
  exemptions on `getInitialView`, `getGlanceView` and `getServiceDelegate`.
- Glance and background each get 64 KB.
- Glance drawing area is about 274x128 (41mm) and 318x150 (45mm). Use
  `dc.getWidth()` / `dc.getHeight()`, never fixed pixels.
- `getFontHeight()` overstates number fonts by more than 2x. Do not size
  layout from it.
- The 41mm needs a 54x54 launcher icon, the 45mm 65x65.
- Simulator: reset all app data after changing property defaults; the
  background event only fires after clicking OK in its dialog; layout can only
  be judged by looking at it.
- Simulator, glance: `Settings > Glance Launch Mode > Launch in Glance Mode`,
  then relaunch. The glance opens at the top of the round screen, where the
  bezel clips its right side; drag down on the screen to scroll it to the
  centre before judging it. Tapping it opens the detail page.
- Simulator: `File > Kill App` before relaunching, or the old binary keeps
  running. `Reset All App Data` did not clear storage (SDK 9.2.0); with the app
  killed, remove `$TMPDIR/com.garmin.connectiq/GARMIN/APPS/DATA/CLAUDE-USAGE-*.DAT`
  and `.IDX` instead. Selecting a row in `Edit Persistent Storage` crashed the
  simulator.
- The developer key from the old project can be reused. Never commit it.
