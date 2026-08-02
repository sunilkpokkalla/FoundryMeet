"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onPushOutboxCreated = exports.onMailOutboxCreated = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const params_1 = require("firebase-functions/params");
const firebase_functions_1 = require("firebase-functions");
admin.initializeApp();
// Optional — set with: firebase functions:config:set is deprecated;
// use params / console env, or `firebase functions:secrets:set` after Blaze upgrade.
const resendApiKey = (0, params_1.defineString)("RESEND_API_KEY", { default: "" });
const mailFrom = (0, params_1.defineString)("MAIL_FROM", {
    default: "FoundryMeet <onboarding@resend.dev>",
});
exports.onMailOutboxCreated = (0, firestore_1.onDocumentCreated)({
    document: "mailOutbox/{mailId}",
}, async (event) => {
    const snap = event.data;
    if (!snap)
        return;
    const data = snap.data();
    if (data.status && data.status !== "pending")
        return;
    const apiKey = resendApiKey.value();
    const from = mailFrom.value() || "FoundryMeet <noreply@foundrymeet.com>";
    const recipients = (data.to || []).filter(Boolean);
    if (!apiKey) {
        await snap.ref.set({
            status: "skipped",
            errorMessage: "RESEND_API_KEY not configured",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        firebase_functions_1.logger.warn("mail skipped: missing RESEND_API_KEY");
        return;
    }
    if (recipients.length === 0) {
        await snap.ref.set({
            status: "failed",
            errorMessage: "No recipients",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
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
        await snap.ref.set({
            status: "sent",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        firebase_functions_1.logger.error("mail send failed", message);
        await snap.ref.set({
            status: "failed",
            errorMessage: message,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
});
exports.onPushOutboxCreated = (0, firestore_1.onDocumentCreated)("pushOutbox/{pushId}", async (event) => {
    const snap = event.data;
    if (!snap)
        return;
    const data = snap.data();
    if (data.status && data.status !== "pending")
        return;
    const recipientIds = data.recipientIds || [];
    if (recipientIds.length === 0) {
        await snap.ref.set({
            status: "failed",
            errorMessage: "No recipients",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        return;
    }
    const tokens = [];
    for (const uid of recipientIds) {
        const userSnap = await admin.firestore().collection("users").doc(uid).get();
        const userTokens = userSnap.data()?.fcmTokens || [];
        tokens.push(...userTokens);
    }
    const uniqueTokens = Array.from(new Set(tokens));
    if (uniqueTokens.length === 0) {
        await snap.ref.set({
            status: "skipped",
            errorMessage: "No FCM tokens",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
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
        await snap.ref.set({
            status: "sent",
            successCount: response.successCount,
            failureCount: response.failureCount,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        firebase_functions_1.logger.error("push send failed", message);
        await snap.ref.set({
            status: "failed",
            errorMessage: message,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
});
//# sourceMappingURL=index.js.map