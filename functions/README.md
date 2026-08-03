# FoundryMeet Cloud Functions

Delivers in-app push via FCM (`pushOutbox`). No email provider is configured.

## Deploy

```bash
cd functions && npm install && npm run build
cd .. && npx firebase deploy --only functions --force
```
