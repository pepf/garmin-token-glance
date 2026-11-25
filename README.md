# Token Glance

A Garmin glance that shows how much of your Claude subscription limits you have
used: the 5-hour and 7-day percentage, time until reset, and a pace tick that
tells you whether you are burning faster than the window allows.

Sideloaded, for personal use. See [Supported models](#supported-models).

<img width="1000" alt="Garmin Token Glance Screenshots" src="https://github.com/user-attachments/assets/978e4981-b348-4916-a8fe-3265048450ce" />

## Supported models

| Watch | Sizes | Build (`<device>`) |
|---|---|---|
| Fenix 9 | 43 mm | `fenix943mm` |
| Fenix 9 | 47, 51 mm | `fenix947mm` |
| Fenix 9 Pro | 43 mm | `fenix9pro43mm` |
| Fenix 9 Pro | 47 mm | `fenix9pro47mm` |
| Fenix 9 Pro | 51 mm | `fenix9pro51mm` |
| Fenix 9 Pro Solar | 47 mm | `fenix9prosolar47mm` |
| Fenix 9 Pro Solar | 51 mm | `fenix9prosolar51mm` |
| Fenix 8 | 43 mm | `fenix843mm` |
| Fenix 8, tactix 8, quatix 8 | 47, 51 mm | `fenix847mm` |
| Fenix 8 Pro, Fenix 8 MicroLED, quatix 8 Pro | 47, 51 mm | `fenix8pro47mm` |
| Fenix 8 Solar | 47 mm | `fenix8solar47mm` |
| Fenix 8 Solar, tactix 8 Solar | 51 mm | `fenix8solar51mm` |
| Venu 4 | 41 mm | `venu441mm` |
| Venu 4, D2 Air X15 | 45 mm | `venu445mm` |
| Instinct 3 Solar, Solar Tactical | 45, 50 mm | `instinct3solar45mm` |

Each build was checked in the Connect IQ simulator (glance and detail page). The
Fenix and Instinct builds have not been tried on a real watch.
For any other model, see step 7 of [instructions.md](instructions.md).

## How it works

### Components

```mermaid
flowchart LR
    you(["👤 You"]) --> watch["⌚ Garmin watch"] --> relay
    subgraph gcp["Google Cloud"]
        relay["Relay function"]
        relay <--> bucket[("Storage bucket")]
        sched["Scheduler"] --> relay
    end
    relay --> claude["Claude"]

    classDef accent fill:#D97757,stroke:#B85C3E,color:#fff
    class relay accent
    style gcp fill:none,stroke:#888,stroke-dasharray:4
```

### Flow

```mermaid
sequenceDiagram
    actor You
    participant Watch as Garmin watch
    participant Relay
    participant Claude

    loop Every 10 minutes
        Note over Relay: Scheduler calls POST /poll
        Relay->>Claude: One tiny Haiku turn
        Claude-->>Relay: 5h and 7d usage
        Note over Relay: Save to bucket
    end

    loop Every 5 minutes
        Watch->>Relay: GET /usage
        Note over Relay: Read from bucket
        Relay-->>Watch: Latest usage
        Note over Watch: Store snapshot
    end

    You->>Watch: Look at the glance
    Watch-->>You: Usage, time to reset, pace
```

1. Cloud Scheduler calls the relay's `/poll` every 10 minutes.
2. The relay runs one minimal Claude Code turn with your `claude setup-token`
   token. The response stream includes a `rate_limit_event` carrying your
   account-wide 5-hour and 7-day usage. It stores the numbers as one small
   JSON file in a private bucket.
3. The watch fetches `/usage` in the background every 5 minutes (through the
   phone's Garmin Connect app) and draws the glance from the stored snapshot.
   Countdowns and the pace tick are computed on the watch, so they stay right
   between fetches.

The limits are account-wide, so it covers the desktop app, the CLI and
claude.ai. Nothing runs on your computer. Each poll costs under 1,000 Haiku
tokens against your own limits.

Caveat: `rate_limit_event` is not a documented API. If a Claude Code update
drops it, `/poll` returns 500 and the watch keeps showing the last data.

## Layout

| Path | What |
|---|---|
| `relay/` | Cloud Function (`index.js`, ~70 lines) and `deploy.sh` |
| `watch/` | Connect IQ app in Monkey C (glance, detail page, background fetch) |
| `env.example` | Template for `~/.claude/token-glance/env`, which holds all secrets |
| `SPEC.md` | Design notes and decisions |
| `instructions.md` | Step-by-step setup, written for you or a coding agent |

## Setup

See [instructions.md](instructions.md). It covers the Google Cloud project,
the Claude token, deploying the relay, the scheduler, building the watch app
and sideloading it. You can hand it to a coding agent (Claude Code or
similar) and have it walk you through.

## Installing on your watch (sideload)

This is a personal build, not a Connect IQ Store app. Settings in Garmin
Connect are not available for sideloaded apps, so the relay host and token are
compiled in from `watch/resources/properties/properties.xml` (gitignored).

1. Build: `./watch/build.sh` produces `watch/bin/claude-usage-<device>.prg` for
   every device under [Supported models](#supported-models). Pick the one for
   your watch.
2. Connect the watch to your computer with its USB cable.
   - macOS: Garmin watches use MTP, so they do not show up in Finder. Use
     [OpenMTP](https://openmtp.ganeshrvel.com/) (free) to browse the watch.
   - Windows/Linux: the watch appears as a media device in the file manager.
3. Copy the `.prg` into the `GARMIN/APPS/` folder on the watch.
4. Unplug. The app appears under apps; add **Claude Usage** to your glance
   loop from the watch's glance settings.
5. Give it a few minutes: the first background fetch runs within 5 minutes of
   the app first starting, and needs the phone with Garmin Connect nearby.

To update, copy the new `.prg` into `GARMIN/APPS/` and unplug. The old one is
usually not listed there: newer watches move installed apps to hidden storage.
To remove, use Garmin Express or the Connect IQ store on the watch.

## Security

- No secrets are in this repository. They live in
  `~/.claude/token-glance/env` (mode 600), in Secret Manager, and in your
  local, gitignored `properties.xml`.
- The relay token is only ever sent in the `Authorization` header, never in a
  URL, because Cloud Run access logs record full URLs.
- The Claude token is valid for one year. Revoke it at
  claude.ai/settings/claude-code if it leaks.
- Your Connect IQ `developer_key` signs your builds. Keep it out of git.
