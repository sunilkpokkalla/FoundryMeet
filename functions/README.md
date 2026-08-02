# FoundryMeet Cloud Functions

Delivers:
- `mailOutbox` → Resend email (with optional `.ics` attachment)
- `pushOutbox` → FCM multicast

## Status

Functions are deployed to project `foundrymeet` (`us-central1`):
- `onMailOutboxCreated`
- `onPushOutboxCreated`

Without a Resend key, mail docs are marked `skipped`.

## Add Resend (real outbound email)

1. Create an API key at https://resend.com
2. Put it in `functions/.env`:

```
RESEND_API_KEY=re_xxx
MAIL_FROM=FoundryMeet <onboarding@resend.dev>
```

3. Redeploy:

```bash
cd foundrymeet-web
npx firebase deploy --only functions --force
```

## Local build

```bash
cd functions
npm install
npm run build
```
