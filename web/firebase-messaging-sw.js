importScripts(
  "https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js",
);
importScripts(
  "https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js",
);

firebase.initializeApp({
  apiKey: "AIzaSyB4oV543GxGOAAxgDIr-oCf7LQV1H53WrM",
  projectId: "mates-8238c",
  messagingSenderId: "725363533702",
  appId: "1:725363533702:web:118ed379b2cef3058aee07",
  storageBucket: "mates-8238c.firebasestorage.app",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || "New notification";
  const body = payload.notification?.body || "";
  return self.registration.showNotification(title, { body });
});
