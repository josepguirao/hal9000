# ANDORRA 24 — Browser Use + Playwright, Plan A

Target (and only target): existing Google Cloud VM `andorra24-runway-runner`, project `andorra-24-live`, zone `us-central1-c`.

This package installs the open-source Browser Use Python library, Playwright/Chromium and a non-privileged hourly smoke-check timer. The installer reads GCE metadata to REFUSE installation on other machines, especially the LIVE streaming VM `andorra24-stream`.

It does not attempt to extract cookies or credentials, bypass 2FA/CAPTCHA, log in to Runway, generate a video, publish to YouTube, change IAM or buy credits. It does not enable a Runway automation worker before its account, terms, assets and idempotency are verified.

To install once, from an authorized administrator session ON THE RUNNER VM, run:

```sh
git clone --depth 1 --branch andorra24-browser-use-plan-a https://github.com/josepguirao/hal9000.git /tmp/andorra24-browser-install
sudo bash /tmp/andorra24-browser-install/andorra24/browser-use/install.sh
```

Verify:
```sh
sudo systemctl status andorra24-browser-preflight.timer --no-pager
sudo journalctl -u andorra24-browser-preflight.service -n 30 --no-pager
```

Next integration, after installation: authorized Runway Web session with persistent legitimate login; inspect Character Script to Video with user-approved image plus existing MP3, connect to n8n ID Ey9B1PKKqSmRRkI7, enforce YYYY-MM-DD + franja idempotency and verification before automatic YouTube upload. **Running this installer is not evidence that the video pipeline works.**

Browser Use library is open source; LLM inference and hosted browser services, if later connected, may incur separate charges and need explicit authorization.
