# FoundryMeet Cloud Functions

Delivers:
- `mailOutbox` → Resend email (with optional `.ics` attachment)
- `pushOutbox` → FCM multicast

## Setup

```bash
cd functions
npm install
npm run build
```

Set secrets:

```bash
firebase functions:secrets:set RESEND_API_KEY
firebase functions:secrets:set MAIL_FROM
# example MAIL_FROM: FoundryMeet <onboarding@resend.dev>
```

Deploy:

```bash
firebase deploy --only functions,firestore:rules,storage
```

Enable **Cloud Messaging** and **Storage** in the Firebase console for project `foundrymeet`.
