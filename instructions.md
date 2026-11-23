# Setup instructions

Step-by-step setup for Token Glance, from an empty Google Cloud project to the
glance on your wrist. Written so a person or a coding agent (Claude Code,
Cursor, Codex, ...) can follow it top to bottom. Read the [README](README.md)
first for how the pieces fit together.

> **Agents:** run the steps in order and check each one's expected result
> before moving on. Never print, log, commit or paste the values of
> `CLAUDE_TOKEN` or `TOKEN`. Read them from `~/.claude/token-glance/env` with
> `source`, and pass them to commands through variables or files. Steps marked
> **(you)** need the person at the keyboard: a browser sign-in, a payment
> method, or the physical watch.

Time: about 45 minutes. Cost: the Google Cloud free tier covers this usage;
a billing account is still required.

## 0. Prerequisites

- A Claude Pro or Max subscription.
- A Garmin watch with Connect IQ glances. The app targets `venu441mm`,
  `venu445mm` and `instinct3solar45mm`; for another model see step 7.
- macOS, Linux or Windows (WSL) with:
  - [Claude Code](https://docs.claude.com/en/docs/claude-code) (`claude`)
  - [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) (`gcloud`)
  - Node.js 22 (only to sanity-check the relay locally; optional)
  - Java 17+ (the Connect IQ compiler needs it)
  - [Connect IQ SDK Manager](https://developer.garmin.com/connect-iq/sdk/):
    install the latest SDK and the device files for your watch. **(you)**,
    it needs a Garmin account sign-in.

## 1. Local secrets file

All secrets live in one file outside the repo.

```bash
mkdir -p ~/.claude/token-glance
cp env.example ~/.claude/token-glance/env
chmod 600 ~/.claude/token-glance/env
```

Generate the relay token (26 chars of `a-z2-7`, the only characters the
Garmin settings keyboard can type) and write it into the file:

```bash
t=$(LC_ALL=C tr -dc 'a-z2-7' </dev/urandom | head -c 26)
sed -i.bak "s/^TOKEN=.*/TOKEN=$t/" ~/.claude/token-glance/env && rm ~/.claude/token-glance/env.bak
unset t
```

**(you)** Create a long-lived Claude Code token and paste it after
`CLAUDE_TOKEN=` in the env file yourself:

```bash
claude setup-token
```

Fill `GCP_ACCOUNT` (your Google account email) now. `GCP_PROJECT` and
`GCP_SERVICE_ACCOUNT` are set in step 2.

Expected: `grep -c '=.\+' ~/.claude/token-glance/env` counts at least 3
filled lines.

## 2. Google Cloud project

**(you)** Sign in, then create the project and link billing:

```bash
gcloud auth login
```

```bash
source ~/.claude/token-glance/env
export CLOUDSDK_CORE_ACCOUNT="$GCP_ACCOUNT"
export PROJECT=token-glance-$RANDOM     # project ids are global; pick your own
gcloud projects create "$PROJECT"
gcloud billing accounts list            # (you) pick one
gcloud billing projects link "$PROJECT" --billing-account=<ACCOUNT_ID>
export CLOUDSDK_CORE_PROJECT="$PROJECT"
```

Write `GCP_PROJECT=$PROJECT` and
`GCP_SERVICE_ACCOUNT=usage-relay@$PROJECT.iam.gserviceaccount.com` into the
env file.

Keep `CLOUDSDK_CORE_ACCOUNT` and `CLOUDSDK_CORE_PROJECT` exported for every
command below, so gcloud never targets a different default account.

Enable the APIs:

```bash
gcloud services enable cloudfunctions.googleapis.com run.googleapis.com \
  cloudbuild.googleapis.com artifactregistry.googleapis.com \
  firestore.googleapis.com secretmanager.googleapis.com \
  cloudscheduler.googleapis.com
```

### Firestore

The relay expects a named database called `token-glance`:

```bash
gcloud firestore databases create --database=token-glance \
  --location=europe-west4 --type=firestore-native
```

### Service account

```bash
gcloud iam service-accounts create usage-relay --display-name="Token Glance relay"
SA="usage-relay@$PROJECT.iam.gserviceaccount.com"
gcloud projects add-iam-policy-binding "$PROJECT" \
  --member="serviceAccount:$SA" --role=roles/datastore.user --condition=None
```

### Claude token in Secret Manager

Pipe it from the env file so it never appears on the command line:

```bash
source ~/.claude/token-glance/env
printf '%s' "$CLAUDE_TOKEN" | gcloud secrets create claude-token --data-file=-
gcloud secrets add-iam-policy-binding claude-token \
  --member="serviceAccount:$SA" --role=roles/secretmanager.secretAccessor
```

## 3. Deploy the relay

```bash
./relay/deploy.sh
```

The script reads everything from the env file and prints the function URL
when done (first deploy takes a few minutes). Write it into the env file as
`RELAY_URL=https://...`.

If deploy fails on permissions for the Cloud Build service account, grant
`roles/cloudbuild.builds.builder` to
`<PROJECT_NUMBER>-compute@developer.gserviceaccount.com` and retry.

Expected:

```bash
source ~/.claude/token-glance/env
curl -s -o /dev/null -w '%{http_code}\n' "$RELAY_URL/usage"                                    # 401
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $TOKEN" "$RELAY_URL/usage"  # 204 (no data yet)
curl -s -X POST -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $TOKEN" "$RELAY_URL/poll"  # 204, ~7 s
curl -s -H "Authorization: Bearer $TOKEN" "$RELAY_URL/usage"                                   # {"h5":..,"r5":..,...}
```

A 500 from `/poll` means the Claude call failed; check
`gcloud functions logs read usage-relay --gen2 --region=europe-west4`.

## 4. Scheduler

Polls every 10 minutes. The header is passed from a file so the token stays
off the command line:

```bash
source ~/.claude/token-glance/env
h=$(mktemp); printf -- '--headers: "Authorization=Bearer %s"\n' "$TOKEN" > "$h"
gcloud scheduler jobs create http usage-poll --location=europe-west1 \
  --schedule='*/10 * * * *' --time-zone=Etc/UTC \
  --uri="$RELAY_URL/poll" --http-method=POST \
  --attempt-deadline=90s --flags-file="$h" --format=none
rm -f "$h"
```

Expected: `gcloud scheduler jobs run usage-poll --location=europe-west1`,
wait 15 seconds, then `/usage` returns a fresh `ts`.

## 5. Developer key

Connect IQ builds are signed with a key you create once. Keep it; a new key
means reinstalling the app.

```bash
cd watch
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key -nocrypt
rm developer_key.pem
```

`watch/developer_key` is gitignored.

## 6. Build the watch app

Sideloaded apps cannot be configured from Garmin Connect, so the relay host
and token are compiled in:

```bash
source ~/.claude/token-glance/env
host=${RELAY_URL#https://}; host=${host%/}
cat > watch/resources/properties/properties.xml <<EOF
<?xml version="1.0"?>
<properties>
    <property id="relayHost" type="string">$host</property>
    <property id="token" type="string">$TOKEN</property>
</properties>
EOF
./watch/build.sh
```

`properties.xml` is gitignored. `watch/properties.example.xml` is the
committed template.

`build.sh` finds the SDK through
`~/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg`, which the
SDK Manager writes on macOS. On Linux, edit the `SDK=` line to point at your
SDK folder.

Expected: `watch/bin/claude-usage-<device>.prg` for `venu441mm`, `venu445mm`
and `instinct3solar45mm`.

Optional, in the simulator: start it from the SDK Manager, then
`./watch/build.sh run venu445mm`. Use **Settings > Glance Launch Mode >
Launch in Glance Mode** to see the glance. The background fetch only fires
after you confirm its dialog.

## 7. Other watch models

Add your device id to `<iq:products>` in `watch/manifest.xml` and to the loop
in `watch/build.sh`. Device ids are the folder names under the SDK's
`Devices/` directory. The device must support glances and API level 4.0+.
Check the launcher icon size the device wants (see `resources-venu441mm/` for
an override example).

## 8. Sideload to the watch (you)

1. Connect the watch by USB.
2. macOS: open [OpenMTP](https://openmtp.ganeshrvel.com/) (the watch uses MTP
   and does not appear in Finder). Windows/Linux: open it as a media device.
3. Copy the `.prg` for your size into `GARMIN/APPS/`.
4. Unplug, then add **Claude Usage** to the glance loop in the watch's glance
   settings.

Expected: within about 5 minutes, with the phone and Garmin Connect nearby,
the glance shows your percentages. Before that it shows `Waiting for data`.

## Maintenance

- **Rotate the relay token:** generate a new `TOKEN` (step 1), redeploy
  (step 3), update the scheduler header the same way as step 4 but with
  `gcloud scheduler jobs update http usage-poll --location=europe-west1` and
  `--update-headers:` in the flags file, rebuild and resideload the watch (steps 6 and 8).
- **Claude token expires after a year:** run `claude setup-token` again,
  then `printf '%s' "$CLAUDE_TOKEN" | gcloud secrets versions add claude-token --data-file=-`.
  The function picks up `latest` on its next cold start; redeploy to force it.
- **Turn it off:** `gcloud scheduler jobs pause usage-poll --location=europe-west1`.
