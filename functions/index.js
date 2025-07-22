// Import the necessary Firebase modules
const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Initialize the Admin SDK
admin.initializeApp();

/**
 * Cloud Function that triggers when a new document is created in the 'announcements' collection.
 * It sends a push notification to all users.
 */
exports.sendAnnouncementNotification = functions
  .region("asia-southeast1") // Specify the region closest to your users
  .firestore.document("announcements/{announcementId}")
  .onCreate(async (snapshot, context) => {
    // Get the data of the new announcement
    const announcementData = snapshot.data();
    const authorName = announcementData.authorName || "ผู้ดูแลระบบ";
    let messageBody = announcementData.text || "มีประกาศใหม่";

    // If the message is just an image, change the body text
    if (!announcementData.text && announcementData.imageUrl) {
        messageBody = `${authorName} ได้ส่งรูปภาพ`;
    }

    // 1. Get all documents from the 'users' collection
    const usersSnapshot = await admin.firestore().collection("users").get();

    // 2. Collect all FCM tokens from all users
    const allTokens = [];
    usersSnapshot.forEach((doc) => {
      const userData = doc.data();
      // Check if the user has a list of fcmTokens and it's not empty
      if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
        // Add all tokens from this user to our master list
        allTokens.push(...userData.fcmTokens);
      }
    });

    // 3. Remove duplicate tokens, if any
    const uniqueTokens = [...new Set(allTokens)];

    // 4. Check if there are any tokens to send to
    if (uniqueTokens.length === 0) {
      console.log("No FCM tokens found. No notifications sent.");
      return null;
    }

    // 5. Construct the notification payload
    const payload = {
      notification: {
        title: `ประกาศใหม่จาก: ${authorName}`,
        body: messageBody,
        sound: "default",
      },
      data: {
        // You can add custom data here to handle clicks
        "click_action": "FLUTTER_NOTIFICATION_CLICK",
        "screen": "announcement",
      },
    };

    // 6. Send the notification to all unique tokens
    console.log(`Sending notification to ${uniqueTokens.length} tokens.`);
    try {
      const response = await admin.messaging().sendToDevice(uniqueTokens, payload);
      console.log("Successfully sent message:", response);
      // You can also handle errors and remove invalid tokens here
    } catch (error) {
      console.log("Error sending message:", error);
    }

    return null;
  });
