import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { defineString } from "firebase-functions/params";
import { logger } from "firebase-functions";

admin.initializeApp();

// Optional — set with: firebase functions:config:set is deprecated;
// use params / console env, or `firebase functions:secrets:set` after Blaze upgrade.
const resendApiKey = defineString("RESEND_API_KEY", { default: "" });
const mailFrom = defineString("MAIL_FROM", {
  default: "FoundryMeet <onboarding@resend.dev>",
});

type MailDoc = {
  to?: string[];
  subject?: string;
  htmlBody?: string;
  textBody?: string;
  icsContent?: string;
  status?: string;
};

type PushDoc = {
  recipientIds?: string[];
  title?: string;
  body?: string;
  threadId?: string;
  status?: string;
};

export const onMailOutboxCreated = onDocumentCreated(
  {
    document: "mailOutbox/{mailId}",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data() as MailDoc;
    if (data.status && data.status !== "pending") return;

    const apiKey = resendApiKey.value();
    const from = mailFrom.value() || "FoundryMeet <noreply@foundrymeet.com>";
    const recipients = (data.to || []).filter(Boolean);

    if (!apiKey) {
      await snap.ref.set(
        {
          status: "skipped",
          errorMessage: "RESEND_API_KEY not configured",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      logger.warn("mail skipped: missing RESEND_API_KEY");
      return;
    }

    if (recipients.length === 0) {
      await snap.ref.set(
        {
          status: "failed",
          errorMessage: "No recipients",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return;
    }

    try {
      const attachments = data.icsContent
        ? [
            {
              filename: "invite.ics",
              content: Buffer.from(data.icsContent).toString("base64"),
            },
          ]
        : undefined;

      const response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from,
          to: recipients,
          subject: data.subject || "FoundryMeet",
          html: data.htmlBody || "",
          text: data.textBody || "",
          attachments,
        }),
      });

      if (!response.ok) {
        const errText = await response.text();
        throw new Error(`Resend ${response.status}: ${errText}`);
      }

      await snap.ref.set(
        {
          status: "sent",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      logger.error("mail send failed", message);
      await snap.ref.set(
        {
          status: "failed",
          errorMessage: message,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
  }
);

export const onPushOutboxCreated = onDocumentCreated(
  "pushOutbox/{pushId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data() as PushDoc;
    if (data.status && data.status !== "pending") return;

    const recipientIds = data.recipientIds || [];
    if (recipientIds.length === 0) {
      await snap.ref.set(
        {
          status: "failed",
          errorMessage: "No recipients",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return;
    }

    const tokens: string[] = [];
    for (const uid of recipientIds) {
      const userSnap = await admin.firestore().collection("users").doc(uid).get();
      const userTokens = (userSnap.data()?.fcmTokens as string[] | undefined) || [];
      tokens.push(...userTokens);
    }

    const uniqueTokens = Array.from(new Set(tokens));
    if (uniqueTokens.length === 0) {
      await snap.ref.set(
        {
          status: "skipped",
          errorMessage: "No FCM tokens",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return;
    }

    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens: uniqueTokens,
        notification: {
          title: data.title || "FoundryMeet",
          body: data.body || "",
        },
        data: {
          threadId: data.threadId || "",
        },
      });

      await snap.ref.set(
        {
          status: "sent",
          successCount: response.successCount,
          failureCount: response.failureCount,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      logger.error("push send failed", message);
      await snap.ref.set(
        {
          status: "failed",
          errorMessage: message,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
  }
);
