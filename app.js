// ============================================================
// DeepRDMMakademy — app.js
// Système Membres / Inscription / Connexion
// ============================================================

import {
  auth,
  db
} from "./firebase-config.js";

import {
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signInWithPopup,
  GoogleAuthProvider,
  updateProfile,
  onAuthStateChanged,
  signOut
} from "https://www.gstatic.com/firebasejs/11.0.2/firebase-auth.js";

import {
  doc,
  setDoc,
  getDoc,
  serverTimestamp
} from "https://www.gstatic.com/firebasejs/11.0.2/firebase-firestore.js";


// ============================================================
// CONFIGURATION
// ============================================================

const GOOGLE_PROVIDER = new GoogleAuthProvider();

const ROLES = {
  ELEVE: "eleve",
  TRAVAILLEUR: "travailleur",
  ADMINISTRATEUR: "administrateur",
  PUBLICITAIRE: "publicitaire"
};


// ============================================================
// OUTILS
// ============================================================

function escapeHTML(value) {
  return String(value || "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}


function showMessage(message, type = "info") {

  const old = document.getElementById("drm-message");

  if (old) {
    old.remove();
  }

  const box = document.createElement("div");

  box.id = "drm-message";

  box.innerHTML = escapeHTML(message);

  Object.assign(box.style, {
    position: "fixed",
    top: "90px",
    left: "50%",
    transform: "translateX(-50%)",
    zIndex: "999999",
    width: "min(90%, 500px)",
    padding: "16px 20px",
    borderRadius: "14px",
    background:
      type === "error"
        ? "rgba(80,0,35,.96)"
        : "rgba(0,30,55,.96)",
    border:
      type === "error"
        ? "1px solid #ff2bd6"
        : "1px solid #00f0ff",
    color: "#ffffff",
    fontFamily: "Arial, sans-serif",
    fontSize: "14px",
    lineHeight: "1.5",
    boxShadow:
      "0 0 25px rgba(0,240,255,.25)",
    textAlign: "center"
  });

  document.body.appendChild(box);

  setTimeout(() => {
    box.remove();
  }, 5000);
}


// ============================================================
// MODAL PRINCIPAL
// ============================================================

function createModal() {

  const old = document.getElementById("drm-auth-modal");

  if (old) {
    old.remove();
  }

  const modal = document.createElement("div");

  modal.id = "drm-auth-modal";

  modal.innerHTML = `

    <div class="drm-auth-overlay">

      <div class="drm-auth-box">

        <button
          type="button"
          class="drm-close"
          id="drm-close-auth"
        >
          ×
        </button>

        <div class="drm-auth-logo">
          DRM
        </div>

        <h2 id="drm-auth-title">
          Rejoindre DeepRDMMakademy
        </h2>

        <p class="drm-auth-subtitle">
          Créez gratuitement votre accès au campus numérique.
        </p>

        <div
          id="drm-auth-content"
          class="drm-auth-content"
        ></div>

      </div>

    </div>
  `;

  document.body.appendChild(modal);

  injectAuthStyles();

  document
    .getElementById("drm-close-auth")
    .addEventListener("click", closeAuthModal);

  modal
    .querySelector(".drm-auth-overlay")
    .addEventListener("click", function(event) {

      if (event.target === this) {
        closeAuthModal();
      }

    });

  showAccountChoices();
}


function closeAuthModal() {

  const modal =
    document.getElementById("drm-auth-modal");

  if (modal) {
    modal.remove();
  }
}


// ============================================================
// CHOIX DU TYPE DE COMPTE
// ============================================================

function showAccountChoices() {

  const title =
    document.getElementById("drm-auth-title");

  const content =
    document.getElementById("drm-auth-content");

  if (!content) return;

  title.textContent =
    "Choisissez votre profil";

  content.innerHTML = `

    <div class="drm-role-grid">

      <button
        type="button"
        class="drm-role-card"
        data-role="eleve"
      >
        <span class="drm-role-icon">🎓</span>

        <strong>Élève</strong>

        <small>
          Étudier, apprendre et suivre
          les parcours du campus.
        </small>

      </button>


      <button
        type="button"
        class="drm-role-card"
        data-role="travailleur"
      >
        <span class="drm-role-icon">🛠️</span>

        <strong>Travailleur</strong>

        <small>
          Créer, produire, vendre et
          développer des projets.
        </small>

      </button>


      <button
        type="button"
        class="drm-role-card"
        data-role="administrateur"
      >
        <span class="drm-role-icon">🛡️</span>

        <strong>Administrateur</strong>

        <small>
          Demander à rejoindre
          l'équipe administrative.
        </small>

      </button>


      <button
        type="button"
        class="drm-role-card"
        data-role="publicitaire"
      >
        <span class="drm-role-icon">📢</span>

        <strong>Publicitaire</strong>

        <small>
          Entreprise, marque ou
          annonceur.
        </small>

      </button>

    </div>

    <div class="drm-login-link">

      Vous avez déjà un compte ?

      <button
        type="button"
        id="drm-open-login"
      >
        Se connecter
      </button>

    </div>

  `;

  content
    .querySelectorAll("[data-role]")
    .forEach(button => {

      button.addEventListener(
        "click",
        () => {

          showRegistrationForm(
            button.dataset.role
          );

        }
      );

    });

  document
    .getElementById("drm-open-login")
    .addEventListener(
      "click",
      showLoginForm
    );
}


// ============================================================
// FORMULAIRE D'INSCRIPTION
// ============================================================

function showRegistrationForm(role) {

  const title =
    document.getElementById("drm-auth-title");

  const content =
    document.getElementById("drm-auth-content");

  const labels = {

    eleve: "Inscription Élève",

    travailleur:
      "Inscription Travailleur",

    administrateur:
      "Demande Administrateur",

    publicitaire:
      "Inscription Publicitaire"

  };

  title.textContent =
    labels[role] || "Inscription";

  let extraFields = "";

  if (role === "eleve") {

    extraFields = `

      <label>
        Niveau d'étude
        <select
          name="niveau"
          required
        >
          <option value="">
            Choisir
          </option>

          <option>
            Collège
          </option>

          <option>
            Lycée
          </option>

          <option>
            Université
          </option>

          <option>
            Master
          </option>

          <option>
            Doctorat
          </option>

        </select>
      </label>

    `;

  }


  if (role === "travailleur") {

    extraFields = `

      <label>
        Domaine d'activité

        <input
          name="domaine"
          type="text"
          placeholder="Ex : développement, design..."
          required
        >

      </label>

      <label>
        Type d'activité

        <select
          name="activite"
          required
        >

          <option value="">
            Choisir
          </option>

          <option>
            Chercheur
          </option>

          <option>
            Enseignant
          </option>

          <option>
            Créateur
          </option>

          <option>
            Producteur
          </option>

          <option>
            Développeur communauté
          </option>

        </select>

      </label>

    `;

  }


  if (role === "administrateur") {

    extraFields = `

      <label>
        Pourquoi souhaitez-vous devenir administrateur ?

        <textarea
          name="motivation"
          rows="4"
          placeholder="Présentez votre motivation..."
          required
        ></textarea>

      </label>

      <div class="drm-warning">

        🛡️ Votre inscription ne vous donnera
        pas automatiquement les droits administrateur.
        Une validation du Super Admin sera nécessaire.

      </div>

    `;

  }


  if (role === "publicitaire") {

    extraFields = `

      <label>
        Nom de l'entreprise / activité

        <input
          name="entreprise"
          type="text"
          placeholder="Nom de votre entreprise"
          required
        >

      </label>

      <label>
        Type d'annonceur

        <select
          name="type_annonceur"
          required
        >

          <option value="">
            Choisir
          </option>

          <option>
            Entreprise
          </option>

          <option>
            Entrepreneur
          </option>

          <option>
            Association
          </option>

          <option>
            Créateur
          </option>

          <option>
            Organisation
          </option>

        </select>

      </label>

    `;

  }


  content.innerHTML = `

    <form
      id="drm-register-form"
      data-role="${escapeHTML(role)}"
    >

      <label>
        Nom complet

        <input
          name="nom"
          type="text"
          placeholder="Votre nom complet"
          autocomplete="name"
          required
        >

      </label>


      <label>
        Adresse e-mail

        <input
          name="email"
          type="email"
          placeholder="vous@email.com"
          autocomplete="email"
          required
        >

      </label>


      ${extraFields}


      <label>
        Mot de passe

        <input
          name="password"
          type="password"
          placeholder="Minimum 6 caractères"
          minlength="6"
          autocomplete="new-password"
          required
        >

      </label>


      <label>
        Confirmer le mot de passe

        <input
          name="passwordConfirm"
          type="password"
          placeholder="Répétez le mot de passe"
          minlength="6"
          autocomplete="new-password"
          required
        >

      </label>


      <label class="drm-checkbox">

        <input
          name="conditions"
          type="checkbox"
          required
        >

        <span>
          J'accepte les conditions d'utilisation
          de DeepRDMMakademy.
        </span>

      </label>


      <button
        type="submit"
        class="drm-main-button"
      >
        Créer mon compte gratuitement →
      </button>


      <button
        type="button"
        id="drm-back-roles"
        class="drm-secondary-button"
      >
        ← Changer de profil
      </button>

    </form>

  `;


  document
    .getElementById("drm-register-form")
    .addEventListener(
      "submit",
      event => registerUser(
        event,
        role
      )
    );


  document
    .getElementById("drm-back-roles")
    .addEventListener(
      "click",
      showAccountChoices
    );
}


// ============================================================
// INSCRIPTION FIREBASE
// ============================================================

async function registerUser(event, role) {

  event.preventDefault();

  const form = event.target;

  const formData =
    new FormData(form);

  const nom =
    formData.get("nom").trim();

  const email =
    formData.get("email").trim();

  const password =
    formData.get("password");

  const passwordConfirm =
    formData.get("passwordConfirm");


  if (password !== passwordConfirm) {

    showMessage(
      "Les deux mots de passe ne correspondent pas.",
      "error"
    );

    return;
  }


  try {

    const credential =
      await createUserWithEmailAndPassword(
        auth,
        email,
        password
      );

    const user =
      credential.user;


    await updateProfile(
      user,
      {
        displayName: nom
      }
    );


    const profile = {

      uid: user.uid,

      nom: nom,

      email: email,

      type_compte: role,

      statut:

        role === ROLES.ADMINISTRATEUR

          ? "pending"

          : "active",

      createdAt:
        serverTimestamp(),

      updatedAt:
        serverTimestamp()

    };


    if (role === ROLES.ELEVE) {

      profile.niveau =
        formData.get("niveau") || "";

    }


    if (role === ROLES.TRAVAILLEUR) {

      profile.domaine =
        formData.get("domaine") || "";

      profile.activite =
        formData.get("activite") || "";

    }


    if (role === ROLES.ADMINISTRATEUR) {

      profile.motivation =
        formData.get("motivation") || "";

    }


    if (role === ROLES.PUBLICITAIRE) {

      profile.entreprise =
        formData.get("entreprise") || "";

      profile.type_annonceur =
        formData.get("type_annonceur") || "";

    }


    await setDoc(
      doc(db, "users", user.uid),
      profile
    );


    closeAuthModal();


    if (
      role === ROLES.ADMINISTRATEUR
    ) {

      showMessage(
        "Votre compte est créé. Votre demande administrateur est maintenant en attente de validation."
      );

    } else {

      showMessage(
        "Bienvenue sur DeepRDMMakademy ! Votre compte a été créé gratuitement."
      );

    }

  } catch (error) {

    console.error(
      "Erreur inscription Firebase :",
      error
    );

    let message =
      "Impossible de créer le compte.";

    if (
      error.code ===
      "auth/email-already-in-use"
    ) {

      message =
        "Cette adresse e-mail possède déjà un compte.";

    } else if (
      error.code ===
      "auth/invalid-email"
    ) {

      message =
        "L'adresse e-mail n'est pas valide.";

    } else if (
      error.code ===
      "auth/weak-password"
    ) {

      message =
        "Le mot de passe est trop faible.";

    }


    showMessage(
      message,
      "error"
    );

  }

}


// ============================================================
// FORMULAIRE DE CONNEXION
// ============================================================

function showLoginForm() {

  const title =
    document.getElementById("drm-auth-title");

  const content =
    document.getElementById("drm-auth-content");


  title.textContent =
    "Connexion à DeepRDMMakademy";


  content.innerHTML = `

    <form
      id="drm-login-form"
    >

      <label>
        Adresse e-mail

        <input
          name="email"
          type="email"
          placeholder="vous@email.com"
          autocomplete="email"
          required
        >

      </label>


      <label>
        Mot de passe

        <input
          name="password"
          type="password"
          placeholder="Votre mot de passe"
          autocomplete="current-password"
          required
        >

      </label>


      <button
        type="submit"
        class="drm-main-button"
      >
        Se connecter →
      </button>


      <div class="drm-divider">
        OU
      </div>


      <button
        type="button"
        id="drm-google-login"
        class="drm-google-button"
      >
        🔵 Continuer avec Google
      </button>


      <button
        type="button"
        id="drm-back-roles"
        class="drm-secondary-button"
      >
        ← Créer un compte
      </button>

    </form>

  `;


  document
    .getElementById("drm-login-form")
    .addEventListener(
      "submit",
      loginUser
    );


  document
    .getElementById("drm-google-login")
    .addEventListener(
      "click",
      loginWithGoogle
    );


  document
    .getElementById("drm-back-roles")
    .addEventListener(
      "click",
      showAccountChoices
    );

}


// ============================================================
// CONNEXION EMAIL
// ============================================================

async function loginUser(event) {

  event.preventDefault();

  const form =
    event.target;

  const email =
    form.email.value.trim();

  const password =
    form.password.value;


  try {

    const credential =
      await signInWithEmailAndPassword(
        auth,
        email,
        password
      );


    closeAuthModal();


    showMessage(
      `Bienvenue ${credential.user.displayName || ""} !`
    );


  } catch (error) {

    console.error(
      "Erreur connexion :",
      error
    );

    let message =
      "Impossible de vous connecter.";


    if (
      error.code ===
      "auth/invalid-credential"
    ) {

      message =
        "E-mail ou mot de passe incorrect.";

    }


    if (
      error.code ===
      "auth/user-not-found"
    ) {

      message =
        "Aucun compte ne correspond à cette adresse.";

    }


    showMessage(
      message,
      "error"
    );

  }

}


// ============================================================
// CONNEXION GOOGLE
// ============================================================

async function loginWithGoogle() {

  try {

    const result =
      await signInWithPopup(
        auth,
        GOOGLE_PROVIDER
      );

    const user =
      result.user;


    const userRef =
      doc(db, "users", user.uid);

    const existing =
      await getDoc(userRef);


    if (!existing.exists()) {

      await setDoc(
        userRef,
        {

          uid: user.uid,

          nom:
            user.displayName || "",

          email:
            user.email || "",

          type_compte:
            ROLES.ELEVE,

          statut:
            "active",

          provider:
            "google",

          createdAt:
            serverTimestamp(),

          updatedAt:
            serverTimestamp()

        }
      );

    }


    closeAuthModal();


    showMessage(
      `Bienvenue ${user.displayName || ""} !`
    );


  } catch (error) {

    console.error(
      "Erreur Google :",
      error
    );

    showMessage(
      "La connexion avec Google a échoué.",
      "error"
    );

  }

}


// ============================================================
// VÉRIFICATION DU COMPTE CONNECTÉ
// ============================================================

onAuthStateChanged(
  auth,
  async user => {

    if (!user) {
      return;
    }


    try {

      const userRef =
        doc(db, "users", user.uid);

      const snapshot =
        await getDoc(userRef);


      if (
        snapshot.exists()
      ) {

        const data =
          snapshot.data();

        console.log(
          "DeepRDMMakademy — utilisateur connecté :",
          data
        );

      }

    } catch (error) {

      console.error(
        "Erreur récupération profil :",
        error
      );

    }

  }
);


// ============================================================
// DÉCONNEXION
// ============================================================

async function logout() {

  try {

    await signOut(auth);

    showMessage(
      "Vous êtes maintenant déconnecté."
    );

  } catch (error) {

    console.error(
      "Erreur déconnexion :",
      error
    );

  }

}


// ============================================================
// FONCTIONS PUBLIQUES
// ============================================================

// Ces fonctions permettent de conserver
// tes onclick existants dans index.html.

window.inscription = function () {

  createModal();

};


window.connexion = function () {

  createModal();

  setTimeout(
    showLoginForm,
    0
  );

};


window.devenirMembre = function () {

  createModal();

};


window.logoutDeepRDM = logout;


// ============================================================
// POPUP ACCÈS MEMBRE
// ============================================================

window.verifierAccesMembre = async function (
  callback
) {

  if (auth.currentUser) {

    if (
      typeof callback === "function"
    ) {

      callback();

    }

    return true;

  }


  showMessage(
    "Veuillez vous inscrire pour accéder à cette fonctionnalité."
  );

  createModal();

  return false;

};


// ============================================================
// STYLES AUTHENTIFICATION
// ============================================================

function injectAuthStyles() {

  if (
    document.getElementById(
      "drm-auth-styles"
    )
  ) {

    return;

  }


  const style =
    document.createElement("style");

  style.id =
    "drm-auth-styles";


  style.textContent = `

    #drm-auth-modal {

      position: fixed;

      inset: 0;

      z-index: 999990;

    }


    .drm-auth-overlay {

      position: absolute;

      inset: 0;

      display: flex;

      align-items: center;

      justify-content: center;

      padding: 20px;

      background:
        rgba(0,0,15,.88);

      backdrop-filter:
        blur(12px);

      overflow-y: auto;

    }


    .drm-auth-box {

      position: relative;

      width: min(100%, 560px);

      max-height: 92vh;

      overflow-y: auto;

      padding: 28px;

      border-radius: 24px;

      background:
        linear-gradient(
          145deg,
          rgba(4,25,48,.98),
          rgba(3,8,25,.98)
        );

      border:
        1px solid rgba(0,240,255,.55);

      box-shadow:
        0 0 30px rgba(0,240,255,.22),
        0 0 80px rgba(255,0,240,.10);

      color: #ffffff;

      font-family:
        Arial,
        sans-serif;

    }


    .drm-close {

      position: absolute;

      right: 16px;

      top: 12px;

      width: 40px;

      height: 40px;

      border-radius: 50%;

      border:
        1px solid #00f0ff;

      background:
        rgba(0,240,255,.08);

      color: #ffffff;

      font-size: 28px;

      cursor: pointer;

    }


    .drm-auth-logo {

      width: 58px;

      height: 58px;

      display: flex;

      align-items: center;

      justify-content: center;

      margin: 0 auto 15px;

      border-radius: 50%;

      border:
        2px solid #00f0ff;

      color: #00f0ff;

      font-weight: bold;

      box-shadow:
        0 0 20px rgba(0,240,255,.45);

    }


    .drm-auth-box h2 {

      margin:
        0 0 8px;

      text-align: center;

      color: #ffffff;

      font-size: 25px;

    }


    .drm-auth-subtitle {

      margin:
        0 0 24px;

      text-align: center;

      color: #b9d5e7;

      line-height: 1.5;

    }


    .drm-role-grid {

      display: grid;

      grid-template-columns:
        repeat(2, 1fr);

      gap: 12px;

    }


    .drm-role-card {

      min-height: 155px;

      padding: 18px;

      border-radius: 16px;

      border:
        1px solid rgba(0,240,255,.30);

      background:
        linear-gradient(
          145deg,
          rgba(0,50,75,.65),
          rgba(5,15,35,.90)
        );

      color: #ffffff;

      cursor: pointer;

      text-align: left;

      transition:
        .25s ease;

    }


    .drm-role-card:hover {

      transform:
        translateY(-3px);

      border-color:
        #00f0ff;

      box-shadow:
        0 0 22px
        rgba(0,240,255,.20);

    }


    .drm-role-icon {

      display: block;

      font-size: 30px;

      margin-bottom: 10px;

    }


    .drm-role-card strong {

      display: block;

      color: #00f0ff;

      font-size: 17px;

      margin-bottom: 7px;

    }


    .drm-role-card small {

      display: block;

      color: #c4d5e3;

      line-height: 1.4;

    }


    #drm-auth-content label {

      display: block;

      margin-bottom: 14px;

      color: #d8e8f2;

      font-size: 14px;

    }


    #drm-auth-content input,

    #drm-auth-content select,

    #drm-auth-content textarea {

      box-sizing: border-box;

      width: 100%;

      margin-top: 7px;

      padding: 13px;

      border-radius: 10px;

      border:
        1px solid
        rgba(0,240,255,.35);

      outline: none;

      background:
        rgba(0,10,25,.85);

      color: #ffffff;

      font-size: 14px;

    }


    #drm-auth-content textarea {

      resize: vertical;

    }


    #drm-auth-content input:focus,

    #drm-auth-content select:focus,

    #drm-auth-content textarea:focus {

      border-color:
        #00f0ff;

      box-shadow:
        0 0 12px
        rgba(0,240,255,.18);

    }


    .drm-checkbox {

      display: flex !important;

      gap: 9px;

      align-items:
        flex-start;

    }


    .drm-checkbox input {

      width:
        auto !important;

      margin-top: 3px;

    }


    .drm-main-button,

    .drm-secondary-button,

    .drm-google-button {

      width: 100%;

      min-height: 48px;

      margin-top: 8px;

      border-radius: 12px;

      cursor: pointer;

      font-weight: bold;

      font-size: 14px;

    }


    .drm-main-button {

      border:
        1px solid #00f0ff;

      background:
        linear-gradient(
          90deg,
          #00d9ff,
          #00f0ff
        );

      color: #00101b;

      box-shadow:
        0 0 20px
        rgba(0,240,255,.22);

    }


    .drm-secondary-button {

      border:
        1px solid
        rgba(0,240,255,.40);

      background:
        rgba(0,240,255,.06);

      color: #00f0ff;

    }


    .drm-google-button {

      border:
        1px solid
        rgba(255,255,255,.25);

      background:
        rgba(255,255,255,.07);

      color: #ffffff;

    }


    .drm-login-link {

      margin-top: 20px;

      text-align: center;

      color: #9fb5c7;

      font-size: 14px;

    }


    .drm-login-link button {

      border: none;

      background: none;

      color: #00f0ff;

      cursor: pointer;

      font-weight: bold;

    }


    .drm-divider {

      margin: 16px 0;

      text-align: center;

      color: #668096;

      font-size: 12px;

    }


    .drm-warning {

      margin:
        10px 0 18px;

      padding: 12px;

      border-radius: 10px;

      background:
        rgba(255,0,240,.07);

      border:
        1px solid
        rgba(255,0,240,.35);

      color: #e8c9e7;

      line-height: 1.45;

      font-size: 13px;

    }


    @media (max-width: 520px) {

      .drm-auth-overlay {

        align-items:
          flex-start;

        padding:
          15px;

      }


      .drm-auth-box {

        margin-top: 25px;

        padding: 22px;

        border-radius: 20px;

      }


      .drm-role-grid {

        grid-template-columns:
          1fr;

      }


      .drm-role-card {

        min-height:
          auto;

      }

    }

  `;


  document.head.appendChild(style);

}


// ============================================================
// FIN
// ============================================================

console.log(
  "🚀 DeepRDMMakademy app.js chargé."
);
