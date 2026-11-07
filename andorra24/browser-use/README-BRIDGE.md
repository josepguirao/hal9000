# ANDORRA 24 · n8n ↔ Browser Use bridge

Status: **source verified in GitHub; not deployed on runner until Cloud Shell command executes**. Base Browser Use/Playwright installation was separately verified on the existing VM. This bridge does not generate media, click Runway, or publish to YouTube yet.

## Architecture

* Existing machine only: `andorra24-runway-runner`, project `andorra-24-live`, zone `us-central1-c`. Never touch `andorra24-stream`.
* Runner has no inbound Internet service. It makes authenticated **outbound HTTPS** requests to `https://blaxxun.app.n8n.cloud`.
* n8n existing workflow: `Ey9B1PKKqSmRRkI7`. Inspect rather than replace it. A separately imported webhook/queue workflow may be needed if it lacks the right endpoints.
* Persistent SQLite uniqueness by `job_id`; edition key format `YYYY-MM-DD_MATI|MIGDIA|TARDA|NIT|ESPECIAL`.
* The only implemented operations are `ping`, `browser_health`, and `runway_session_check`. They do not use paid provider APIs.
* Bearer authentication: the root-owned server file `/etc/andorra24-browser-use/bridge.env` contains `A24_N8N_PULL_URL`, `A24_N8N_RESULT_URL`, and `A24_N8N_BRIDGE_TOKEN` (24+ random characters). n8n must validate the identical token on BOTH webhook endpoints. Never commit or paste the token into ChatGPT.

## n8n API contract

`GET A24_N8N_PULL_URL` must respond with HTTP 200 JSON body `{}` when idle or:

```json
{"job_id":"a24-2026-11-07-mati-health","edition_key":"2026-11-07_MATI","action":"browser_health"}
```

`POST A24_N8N_RESULT_URL` receives a JSON record with `job_id`, `status`, `result`, and `time` where relevant. Return 2xx to acknowledge receipt. n8n must not repeat a completed job after acknowledgement. The runner has additional duplicate protection. Real job dispatch requires a durable queue in n8n (such as Data Tables) and should not be implemented as a static URL returning the same ID indefinitely. Do not store cookies/credentials in job bodies or logs.

## Deploy

From **authenticated Google Cloud Shell** only:

```bash
curl -fsSL https://raw.githubusercontent.com/josepguirao/hal9000/d58a126c97d00507120f469b409c69340415644b/andorra24/browser-use/deploy-bridge-from-cloud-shell.sh -o /tmp/a24-bridge.sh && bash /tmp/a24-bridge.sh
```

Check for `BRIDGE_INSTALLED_NOT_CONNECTED`, meaning local tests succeeded. This is **not** proof of a working n8n connection. Then create/verify the n8n webhooks, protect their credentials, write `bridge.env` (mode 0600, owned by root), and explicitly enable the service:

```bash
sudo systemctl enable --now andorra24-n8n-bridge.service
sudo systemctl status andorra24-n8n-bridge.service --no-pager
```

Check actual n8n receipt of a `ping` then `browser_health` job before adding any browser UI automation.

## Before paid Runway generation

The presence of a Chromium profile is NOT proof that Runway Web is authenticated. Confirm the operator's session, terms of use, and whether web UI automation is supported for the intended task. Prefer an official authorized provider integration. Do not attempt bypass of MFA, CAPTCHA, rate limiting or access controls. Only if the provider permits, implement and verify a deterministic Character Script to Video workflow with existing image+MP3, original asset preservation, credit accounting, one MP4 per edition, quality control, and idempotent YouTube + playlist + LIVE handoff. **No production render/publish actions are implemented in this branch.**
