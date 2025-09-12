const { setGlobalOptions } = require("firebase-functions");
const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

// Initialize Firebase Admin for full Firestore access
admin.initializeApp();

// Set global options for cost control (10 concurrent instances)
setGlobalOptions({ maxInstances: 10 });

exports.migrateRegistrations = onRequest(async (req, res) => {
  try {
    const db = admin.firestore();
    const users = await db.collection("users").get();
    let migratedCount = 0;
    let deletedCount = 0;

    for (const user of users.docs) {
      const registrations = await user.ref.collection("registrations").get();
      for (const reg of registrations.docs) {
        const data = reg.data();
        let eventId = data.eventId;
        if (eventId && eventId.includes("/")) {
          eventId = eventId.split("/").pop(); // Extract ID from /events/...
        }
        const userId = user.id;

        if (!eventId) {
          logger.warn(`Skipping invalid registration: ${reg.id}`, { userId });
          continue;
        }

        // Write to new location: events/{eventId}/registrations/{userId}
        await db.collection("events")
          .doc(eventId)
          .collection("registrations")
          .doc(userId)
          .set({
            userId: userId,
            eventId: eventId,
            registeredAt: data.registeredOn || admin.firestore.FieldValue.serverTimestamp(),
            status: data.status === "registered" ? "approved" : (data.status || "pending"),
          });

        // Delete old registration
        await reg.ref.delete();
        migratedCount++;
        deletedCount++;
      }
    }

    logger.info(`Migration complete: ${migratedCount} registrations moved, ${deletedCount} old records deleted.`, { structuredData: true });
    res.status(200).send(`Success! Migrated ${migratedCount} registrations. Check Firebase console for details.`);
  } catch (error) {
    logger.error("Migration error:", error, { structuredData: true });
    res.status(500).send(`Error: ${error.message}`);
  }
});