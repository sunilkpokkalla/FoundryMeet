import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";

admin.initializeApp();

type PushDoc = {
  recipientIds?: string[];
  title?: string;
  body?: string;
  threadId?: string;
  chatId?: string;
  status?: string;
};

/** Delivers in-app push reminders via FCM — no email provider required. */
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
          chatId: data.chatId || "",
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
