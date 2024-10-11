const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendNewExamNotification = functions.firestore
    .document("exams/{examId}")
    .onCreate(async (snap, context) => {
      const newExam = snap.data();
      const payload = {
        notification: {
          title: "New Exam Added",
          body: `A new exam for ${newExam.subject} has been added.`,
        },
        data: {
          subject: newExam.subject,
          examId: context.params.examId, // Adding examId as data
        },
      };

      try {
        // Send notification to topic
        const response = await admin.messaging().sendToTopic("exams", payload);
        console.log("Successfully sent message:", response);
      } catch (error) {
        console.error("Error sending message:", error);
      }
    });
