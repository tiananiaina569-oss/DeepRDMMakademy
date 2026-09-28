// ============================================================
// DeepRDMMakademy — Firebase Configuration
// ============================================================
// ⚠️ IMPORTANT : remplace uniquement les valeurs entre "" par
// les informations de TON projet Firebase.
// ============================================================

import { initializeApp } from
  "https://www.gstatic.com/firebasejs/11.0.2/firebase-app.js";

import {
  getAuth
} from
  "https://www.gstatic.com/firebasejs/11.0.2/firebase-auth.js";

import {
  getFirestore
} from
  "https://www.gstatic.com/firebasejs/11.0.2/firebase-firestore.js";


// ============================================================
// 🔥 CONFIGURATION FIREBASE
// ============================================================

const firebaseConfig = {

  apiKey: "TON_API_KEY",

  authDomain: "TON_PROJET.firebaseapp.com",

  projectId: "TON_PROJECT_ID",

  storageBucket: "TON_PROJET.firebasestorage.app",

  messagingSenderId: "TON_SENDER_ID",

  appId: "TON_APP_ID"

};


// ============================================================
// 🚀 INITIALISATION
// ============================================================

const app = initializeApp(firebaseConfig);


// ============================================================
// 🔐 AUTHENTIFICATION
// ============================================================

const auth = getAuth(app);


// ============================================================
// 🗄️ FIRESTORE
// ============================================================

const db = getFirestore(app);


// ============================================================
// 📤 EXPORTS
// ============================================================

export {
  app,
  auth,
  db
};
