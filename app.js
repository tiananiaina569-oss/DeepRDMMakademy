/* =========================================================
   DeepRDMMakademy
   app.js
   Campus numérique — moteur principal de l'accueil
   ========================================================= */

/*
   IMPORTANT
   ----------
   Ce fichier utilise Firebase.

   Le fichier suivant sera créé séparément :
   firebase-config.js

   Il devra exporter :
   firebaseConfig
*/

import { initializeApp } from
    "https://www.gstatic.com/firebasejs/10.12.5/firebase-app.js";

import {
    getAuth,
    createUserWithEmailAndPassword,
    onAuthStateChanged,
    signOut
} from
    "https://www.gstatic.com/firebasejs/10.12.5/firebase-auth.js";

import {
    getFirestore,
    collection,
    addDoc,
    setDoc,
    doc,
    getDoc,
    getDocs,
    query,
    orderBy,
    limit,
    where,
    updateDoc,
    serverTimestamp,
    onSnapshot
} from
    "https://www.gstatic.com/firebasejs/10.12.5/firebase-firestore.js";

import { firebaseConfig } from "./firebase-config.js";

/* =========================================================
   FIREBASE INITIALISATION
   ========================================================= */

const firebaseApp = initializeApp(firebaseConfig);

const auth = getAuth(firebaseApp);
const db = getFirestore(firebaseApp);

/* =========================================================
   GLOBAL STATE
   ========================================================= */

let currentUser = null;
let currentUserData = null;

let unsubscribeNotifications = null;
let unsubscribePublications = null;

const MEMBER_ROLES = [
    "member",
    "student",
    "researcher",
    "educator",
    "developer",
    "responsible",
    "admin",
    "super_admin"
];

const PUBLISHER_ROLES = [
    "technicien",
    "researcher",
    "educator",
    "developer",
    "responsible",
    "admin",
    "super_admin"
];

const ADMIN_ROLES = [
    "admin",
    "super_admin"
];

/* =========================================================
   DOM HELPERS
   ========================================================= */

const $ = (id) => document.getElementById(id);

function showElement(element) {
    if (element) {
        element.classList.remove("hidden");
    }
}

function hideElement(element) {
    if (element) {
        element.classList.add("hidden");
    }
}

function escapeHTML(value = "") {
    return String(value)
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");
}

function formatDate(timestamp) {
    if (!timestamp) {
        return "À l'instant";
    }

    try {
        const date =
            timestamp.toDate
                ? timestamp.toDate()
                : new Date(timestamp);

        return new Intl.DateTimeFormat("fr-FR", {
            dateStyle: "medium",
            timeStyle: "short"
        }).format(date);
    } catch {
        return "Date inconnue";
    }
}

function initials(name = "Membre") {
    const parts = name.trim().split(/\s+/).slice(0, 2);

    return parts
        .map((part) => part.charAt(0).toUpperCase())
        .join("");
}

/* =========================================================
   TOAST
   ========================================================= */

let toastTimer = null;

function showToast(message) {
    const toast = $("toast");

    if (!toast) {
        return;
    }

    toast.textContent = message;
    toast.classList.add("show");

    clearTimeout(toastTimer);

    toastTimer = setTimeout(() => {
        toast.classList.remove("show");
    }, 3500);
}

/* =========================================================
   MODALS
   ========================================================= */

function openModal(id) {
    const modal = $(id);

    if (!modal) {
        return;
    }

    showElement(modal);
    document.body.style.overflow = "hidden";
}

function closeModal(id) {
    const modal = $(id);

    if (!modal) {
        return;
    }

    hideElement(modal);

    const visibleModal =
        document.querySelector(".modal:not(.hidden)");

    if (!visibleModal) {
        document.body.style.overflow = "";
    }
}

function setupModalEvents() {
    document.querySelectorAll("[data-close]").forEach((button) => {
        button.addEventListener("click", () => {
            closeModal(button.dataset.close);
        });
    });

    document.querySelectorAll(".modal").forEach((modal) => {
        modal.addEventListener("click", (event) => {
            if (event.target === modal) {
                closeModal(modal.id);
            }
        });
    });
}

/* =========================================================
   SCROLL TO CAMPUS
   ========================================================= */

window.scrollToCampus = function () {
    const campus = $("campus");

    if (campus) {
        campus.scrollIntoView({
            behavior: "smooth",
            block: "start"
        });
    }
};

/* =========================================================
   FOLLOWERS
   ========================================================= */

async function handleFollowerSignup(event) {
    event.preventDefault();

    const name = $("followerName")?.value.trim();
    const email = $("followerEmail")?.value.trim().toLowerCase();
    const message = $("followMessage");

    if (!name || !email) {
        setFormMessage(
            message,
            "Veuillez remplir tous les champs.",
            "error"
        );
        return;
    }

    try {
        setFormMessage(
            message,
            "Inscription en cours...",
            ""
        );

        /*
           On utilise l'email comme identifiant documentaire.
           Cela évite plusieurs inscriptions avec exactement
           la même adresse.
        */

        const followerId = email
            .replace(/\./g, "_")
            .replace(/@/g, "_at_")
            .replace(/[^a-zA-Z0-9_-]/g, "_");

        await setDoc(
            doc(db, "followers", followerId),
            {
                nom: name,
                email: email,
                actif: true,
                date_inscription: serverTimestamp(),
                source: "campus_home"
            },
            {
                merge: true
            }
        );

        setFormMessage(
            message,
            "Tu suis maintenant DeepRDMMakademy. Bienvenue dans le réseau.",
            "success"
        );

        $("followForm")?.reset();

        showToast("Inscription au suivi réussie.");

        setTimeout(() => {
            closeModal("followModal");
        }, 1800);

    } catch (error) {
        console.error(
            "Erreur follower :",
            error
        );

        setFormMessage(
            message,
            firebaseErrorMessage(error),
            "error"
        );
    }
}

/* =========================================================
   MEMBER REGISTRATION
   ========================================================= */

async function handleMemberRegistration(event) {
    event.preventDefault();

    const firstName =
        $("memberFirstName")?.value.trim();

    const lastName =
        $("memberLastName")?.value.trim();

    const email =
        $("memberEmail")?.value.trim().toLowerCase();

    const password =
        $("memberPassword")?.value;

    const requestedLevel =
        $("memberLevel")?.value;

    const answer1 =
        $("testQuestion1")?.value;

    const answer2 =
        $("testQuestion2")?.value;

    const answer3 =
        $("testQuestion3")?.value;

    const message = $("memberMessage");

    if (
        !firstName ||
        !lastName ||
        !email ||
        !password ||
        !requestedLevel ||
        !answer1 ||
        !answer2 ||
        !answer3
    ) {
        setFormMessage(
            message,
            "Veuillez compléter toutes les informations et le test d'entrée.",
            "error"
        );

        return;
    }

    if (password.length < 8) {
        setFormMessage(
            message,
            "Le mot de passe doit contenir au moins 8 caractères.",
            "error"
        );

        return;
    }

    /*
       Test d'entrée initial.
       Ce test pourra être remplacé plus tard par le vrai
       système pédagogique connecté à la base de données.
    */

    let score = 0;

    if (answer1 === "60") {
        score++;
    }

    if (answer2 === "physique") {
        score++;
    }

    if (answer3 === "10") {
        score++;
    }

    try {
        setFormMessage(
            message,
            "Création du compte...",
            ""
        );

        const credential =
            await createUserWithEmailAndPassword(
                auth,
                email,
                password
            );

        const user = credential.user;

        await setDoc(
            doc(db, "users", user.uid),
            {
                uid: user.uid,

                prenom: firstName,
                nom: lastName,

                email: email,

                role: "candidate",
                status: "pending",

                niveau_demande:
                    requestedLevel,

                niveau_valide: null,

                score_test_entree: score,
                test_entree_total: 3,

                candidature:
                    "en_attente_validation",

                date_creation:
                    serverTimestamp(),

                derniere_connexion:
                    serverTimestamp()
            },
            {
                merge: true
            }
        );

        /*
           Création d'une notification interne pour
           le système administratif.
        */

        await createAdminNotification(
            `Nouvelle candidature : ${firstName} ${lastName}`
        );

        setFormMessage(
            message,
            `Compte créé. Résultat du test : ${score}/3. Ta candidature est maintenant en attente de validation.`,
            "success"
        );

        $("memberForm")?.reset();

        showToast(
            "Compte créé. Candidature envoyée."
        );

    } catch (error) {
        console.error(
            "Erreur inscription :",
            error
        );

        setFormMessage(
            message,
            firebaseErrorMessage(error),
            "error"
        );
    }
}

/* =========================================================
   FORM MESSAGE
   ========================================================= */

function setFormMessage(element, text, type = "") {
    if (!element) {
        return;
    }

    element.textContent = text;
    element.className = "form-message";

    if (type) {
        element.classList.add(type);
    }
}

/* =========================================================
   FIREBASE ERROR TRANSLATION
   ========================================================= */

function firebaseErrorMessage(error) {
    const code = error?.code || "";

    const messages = {
        "auth/email-already-in-use":
            "Cette adresse email possède déjà un compte.",

        "auth/invalid-email":
            "L'adresse email n'est pas valide.",

        "auth/weak-password":
            "Le mot de passe est trop faible.",

        "auth/network-request-failed":
            "Problème de connexion réseau.",

        "permission-denied":
            "Accès refusé par les règles de sécurité Firebase."
    };

    return (
        messages[code] ||
        "Une erreur est survenue. Vérifie les informations puis réessaie."
    );
}

/* =========================================================
   ADMIN NOTIFICATION
   ========================================================= */

async function createAdminNotification(message) {
    try {
        /*
           Cette fonction prépare le système de notification.

           Le ciblage précis des administrateurs sera renforcé
           avec les rôles Firebase/Firestore dans les prochaines
           étapes.
        */

        await addDoc(
            collection(db, "notifications_admin"),
            {
                message,
                lu_ou_non: false,
                type: "candidature",
                date: serverTimestamp()
            }
        );

    } catch (error) {
        /*
           Une erreur ici ne doit pas empêcher la création
           du compte utilisateur.
        */

        console.warn(
            "Notification admin non créée :",
            error
        );
    }
}

/* =========================================================
   AUTHENTICATION STATE
   ========================================================= */

function listenToAuthentication() {
    onAuthStateChanged(
        auth,
        async (user) => {

            currentUser = user;

            if (!user) {
                currentUserData = null;

                updateUserInterface();

                stopNotificationListener();

                return;
            }

            await loadCurrentUserData(user.uid);

            updateUserInterface();

            startNotificationListener(user.uid);
        }
    );
}

/* =========================================================
   LOAD CURRENT USER
   ========================================================= */

async function loadCurrentUserData(uid) {
    try {
        const userReference =
            doc(db, "users", uid);

        const snapshot =
            await getDoc(userReference);

        if (snapshot.exists()) {
            currentUserData =
                snapshot.data();

            return;
        }

        currentUserData = {
            uid,
            email: currentUser?.email || "",
            role: "member"
        };

    } catch (error) {
        console.error(
            "Impossible de charger le profil :",
            error
        );

        currentUserData = {
            uid,
            email: currentUser?.email || "",
            role: "member"
        };
    }
}

/* =========================================================
   USER INTERFACE
   ========================================================= */

function updateUserInterface() {
    const userBar = $("userBar");
    const publishButton = $("publishButton");

    if (!currentUser) {
        hideElement(userBar);
        hideElement(publishButton);

        return;
    }

    showElement(userBar);

    const name =
        currentUserData?.prenom
            ? `${currentUserData.prenom} ${currentUserData.nom || ""}`.trim()
            : currentUser.email || "Membre";

    const role =
        currentUserData?.role || "member";

    if ($("currentUserName")) {
        $("currentUserName").textContent =
            name;
    }

    if ($("currentUserRole")) {
        $("currentUserRole").textContent =
            role;
    }

    if (
        PUBLISHER_ROLES.includes(role) ||
        ADMIN_ROLES.includes(role)
    ) {
        showElement(publishButton);
    } else {
        hideElement(publishButton);
    }
}

/* =========================================================
   PUBLICATIONS
   ========================================================= */

function startPublicationListener() {
    const feed = $("campusFeed");

    if (!feed) {
        return;
    }

    if (unsubscribePublications) {
        unsubscribePublications();
    }

    const publicationsQuery = query(
        collection(db, "publications"),
        orderBy("date", "desc"),
        limit(30)
    );

    unsubscribePublications =
        onSnapshot(
            publicationsQuery,
            (snapshot) => {

                if (snapshot.empty) {
                    feed.innerHTML = `
                        <div class="empty-state">
                            Aucune publication pour le moment.
                            Le Campus sera bientôt actif.
                        </div>
                    `;

                    updateMissionCount(0);

                    return;
                }

                const publications =
                    snapshot.docs.map((document) => ({
                        id: document.id,
                        ...document.data()
                    }));

                renderPublications(
                    publications
                );

                updateMissionCount(
                    publications.filter(
                        (publication) =>
                            publication.type ===
                            "nouvelle_mission"
                    ).length
                );
            },
            (error) => {
                console.error(
                    "Erreur publications :",
                    error
                );

                feed.innerHTML = `
                    <div class="empty-state">
                        Le Mur du Campus est momentanément indisponible.
                    </div>
                `;
            }
        );
}

/* =========================================================
   RENDER PUBLICATIONS
   ========================================================= */

function renderPublications(publications) {
    const feed = $("campusFeed");

    if (!feed) {
        return;
    }

    feed.innerHTML =
        publications
            .map(renderPublication)
            .join("");
}

/* =========================================================
   RENDER ONE PUBLICATION
   ========================================================= */

function renderPublication(publication) {
    const authorName =
        publication.author_name ||
        publication.nom_auteur ||
        "DeepRDMMakademy";

    const role =
        publication.author_role ||
        publication.role ||
        "Campus";

    const content =
        publication.contenu ||
        publication.content ||
        "";

    const type =
        publication.type ||
        "annonce";

    const image =
        publication.image ||
        "";

    const isPinned =
        publication.pinned === true ||
        publication.epingle === true;

    const likes =
        Number(publication.likes_count || 0);

    const superCount =
        Number(publication.super_count || 0);

    const geniusCount =
        Number(publication.genial_count || 0);

    const usefulCount =
        Number(publication.utile_count || 0);

    return `
        <article
            class="publication-card ${isPinned ? "pinned" : ""}"
            data-publication-id="${escapeHTML(publication.id)}"
        >

            ${
                isPinned
                    ? `<span class="pin-label">📌 ÉPINGLÉ</span>`
                    : ""
            }

            <div class="publication-top">

                <div class="publication-author">

                    <div class="author-avatar">
                        ${escapeHTML(initials(authorName))}
                    </div>

                    <div class="author-info">

                        <strong>
                            ${escapeHTML(authorName)}
                        </strong>

                        <small>
                            ${escapeHTML(role)}
                            ·
                            ${escapeHTML(formatDate(publication.date))}
                        </small>

                    </div>

                </div>

                <span class="publication-type">
                    ${escapeHTML(publicationTypeLabel(type))}
                </span>

            </div>

            <div class="publication-content">
                ${escapeHTML(content)}
            </div>

            ${
                image
                    ? `
                        <img
                            class="publication-image"
                            src="${escapeHTML(image)}"
                            alt="Publication DeepRDMMakademy"
                            loading="lazy"
                        >
                    `
                    : ""
            }

            <div class="publication-actions">

                <button
    
