// ============================================================
// DeepRDMMakademy
// app.js
// Campus numérique — Firebase + interface Home
// ============================================================

import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.5/firebase-app.js";

import {
    getAuth,
    createUserWithEmailAndPassword,
    onAuthStateChanged
} from "https://www.gstatic.com/firebasejs/10.12.5/firebase-auth.js";

import {
    getFirestore,
    collection,
    doc,
    setDoc,
    addDoc,
    getDoc,
    onSnapshot,
    query,
    orderBy,
    limit,
    where,
    updateDoc,
    increment,
    serverTimestamp
} from "https://www.gstatic.com/firebasejs/10.12.5/firebase-firestore.js";

import { firebaseConfig } from "./firebase-config.js";


// ============================================================
// INITIALISATION FIREBASE
// ============================================================

let firebaseApp;
let auth;
let db;

try {
    firebaseApp = initializeApp(firebaseConfig);
    auth = getAuth(firebaseApp);
    db = getFirestore(firebaseApp);

    console.log("DeepRDMMakademy — Firebase connecté.");
} catch (error) {
    console.error("Erreur initialisation Firebase :", error);
}


// ============================================================
// OUTILS INTERFACE
// ============================================================

function $(id) {
    return document.getElementById(id);
}

function showElement(id) {
    const element = $(id);

    if (element) {
        element.classList.remove("hidden");
    }
}

function hideElement(id) {
    const element = $(id);

    if (element) {
        element.classList.add("hidden");
    }
}

function showModal(id) {
    const modal = $(id);

    if (!modal) {
        console.error("Modal introuvable :", id);
        return;
    }

    modal.classList.remove("hidden");
    document.body.classList.add("modal-open");
}

function closeModal(id) {
    const modal = $(id);

    if (!modal) {
        return;
    }

    modal.classList.add("hidden");

    const remainingModals = document.querySelectorAll(".modal:not(.hidden)");

    if (remainingModals.length === 0) {
        document.body.classList.remove("modal-open");
    }
}

function showToast(message, type = "info") {
    const toast = $("toast");

    if (!toast) {
        return;
    }

    toast.textContent = message;
    toast.className = `toast ${type}`;

    clearTimeout(window.deepRdmToastTimer);

    window.deepRdmToastTimer = setTimeout(() => {
        toast.className = "toast";
    }, 4500);
}

function setFormMessage(id, message, type = "info") {
    const element = $(id);

    if (!element) {
        return;
    }

    element.textContent = message;
    element.className = `form-message ${type}`;
}


// ============================================================
// NAVIGATION CAMPUS
// ============================================================

window.scrollToCampus = function () {
    const campus = $("campus");

    if (campus) {
        campus.scrollIntoView({
            behavior: "smooth",
            block: "start"
        });
    }
};


// ============================================================
// MODALES — SUIVRE / DEVENIR MEMBRE
// ============================================================

function setupModalButtons() {

    const followButton = $("followButton");

    if (followButton) {
        followButton.addEventListener("click", () => {
            console.log("Bouton Suivre activé.");
            showModal("followModal");
        });
    } else {
        console.warn("Bouton followButton introuvable.");
    }


    const memberButton = $("memberButton");

    if (memberButton) {
        memberButton.addEventListener("click", () => {
            console.log("Bouton Devenir membre activé.");
            showModal("memberModal");
        });
    } else {
        console.warn("Bouton memberButton introuvable.");
    }


    document.querySelectorAll("[data-close]").forEach(button => {

        button.addEventListener("click", () => {

            const modalId = button.dataset.close;

            if (modalId) {
                closeModal(modalId);
            }

        });

    });


    document.querySelectorAll(".modal").forEach(modal => {

        modal.addEventListener("click", event => {

            if (event.target === modal) {
                closeModal(modal.id);
            }

        });

    });


    document.addEventListener("keydown", event => {

        if (event.key === "Escape") {

            document.querySelectorAll(".modal:not(.hidden)").forEach(modal => {
                closeModal(modal.id);
            });

        }

    });
}


// ============================================================
// FOLLOWER — INSCRIPTION AUX ACTUALITÉS
// ============================================================

function setupFollowForm() {

    const form = $("followForm");

    if (!form) {
        return;
    }

    form.addEventListener("submit", async event => {

        event.preventDefault();

        const name = $("followerName")?.value.trim();
        const email = $("followerEmail")?.value.trim().toLowerCase();

        if (!name || !email) {
            setFormMessage(
                "followMessage",
                "Veuillez remplir votre nom et votre email.",
                "error"
            );
            return;
        }

        const submitButton = form.querySelector("button[type='submit']");

        if (submitButton) {
            submitButton.disabled = true;
            submitButton.textContent = "Enregistrement...";
        }

        try {

            if (!db) {
                throw new Error("Firebase Firestore n'est pas initialisé.");
            }

            const followerId = email
                .replace(/[.#$/[\]]/g, "_");

            await setDoc(
                doc(db, "followers", followerId),
                {
                    nom: name,
                    email: email,
                    actif: true,
                    date_inscription: serverTimestamp(),
                    source: "deeprdmmakademy-home"
                },
                {
                    merge: true
                }
            );

            setFormMessage(
                "followMessage",
                "Inscription réussie. Tu recevras les actualités de DeepRDMMakademy.",
                "success"
            );

            form.reset();

            showToast(
                "Tu suis maintenant DeepRDMMakademy.",
                "success"
            );

        } catch (error) {

            console.error("Erreur inscription follower :", error);

            setFormMessage(
                "followMessage",
                getFirebaseErrorMessage(error),
                "error"
            );

        } finally {

            if (submitButton) {
                submitButton.disabled = false;
                submitButton.textContent = "Suivre DeepRDMMakademy";
            }

        }

    });
}


// ============================================================
// ADMISSION — CRÉATION DU COMPTE ÉTUDIANT
// ============================================================

function setupMemberForm() {

    const form = $("memberForm");

    if (!form) {
        return;
    }

    form.addEventListener("submit", async event => {

        event.preventDefault();

        const firstName = $("memberFirstName")?.value.trim();
        const lastName = $("memberLastName")?.value.trim();
        const email = $("memberEmail")?.value.trim().toLowerCase();
        const password = $("memberPassword")?.value;
        const level = $("memberLevel")?.value;

        const answer1 = $("testQuestion1")?.value;
        const answer2 = $("testQuestion2")?.value;
        const answer3 = $("testQuestion3")?.value;


        if (
            !firstName ||
            !lastName ||
            !email ||
            !password ||
            !level ||
            !answer1 ||
            !answer2 ||
            !answer3
        ) {

            setFormMessage(
                "memberMessage",
                "Veuillez remplir toutes les informations et répondre aux 3 questions.",
                "error"
            );

            return;
        }


        if (password.length < 8) {

            setFormMessage(
                "memberMessage",
                "Le mot de passe doit contenir au moins 8 caractères.",
                "error"
            );

            return;
        }


        // Correction du test d'entrée
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


        const submitButton = form.querySelector("button[type='submit']");

        if (submitButton) {
            submitButton.disabled = true;
            submitButton.textContent = "Création du compte...";
        }


        try {

            if (!auth || !db) {
                throw new Error(
                    "Firebase n'est pas correctement initialisé."
                );
            }


            // ------------------------------------------------
            // 1. CRÉATION DU COMPTE FIREBASE AUTHENTICATION
            // ------------------------------------------------

            const credential =
                await createUserWithEmailAndPassword(
                    auth,
                    email,
                    password
                );

            const user = credential.user;


            // ------------------------------------------------
            // 2. CRÉATION DU PROFIL FIRESTORE
            // ------------------------------------------------

            await setDoc(
                doc(db, "users", user.uid),
                {
                    uid: user.uid,
                    prenom: firstName,
                    nom: lastName,
                    email: email,

                    role: "candidate",

                    status: "pending",

                    niveau_demande: level,
                    niveau_valide: null,

                    score_test_entree: score,
                    test_entree_total: 3,

                    candidature: "en_attente_validation",

                    date_creation: serverTimestamp(),
                    derniere_connexion: serverTimestamp()
                }
            );


            // ------------------------------------------------
            // 3. NOTIFICATION ADMIN
            // ------------------------------------------------

            await addDoc(
                collection(db, "notifications_admin"),
                {
                    type: "nouvelle_candidature",

                    message:
                        `${firstName} ${lastName} vient de déposer une candidature.`,

                    user_id: user.uid,

                    email: email,

                    niveau_demande: level,

                    score_test: score,

                    lu_ou_non: false,

                    date: serverTimestamp()
                }
            );


            // ------------------------------------------------
            // 4. CONFIRMATION
            // ------------------------------------------------

            setFormMessage(
                "memberMessage",
                `Candidature envoyée avec succès. Score au test : ${score}/3. Ton dossier est maintenant en attente de validation par DeepRDMMakademy.`,
                "success"
            );


            form.reset();

            showToast(
                "Compte créé. Candidature envoyée.",
                "success"
            );


            setTimeout(() => {
                closeModal("memberModal");
            }, 4000);


        } catch (error) {

            console.error(
                "Erreur création compte :",
                error
            );

            setFormMessage(
                "memberMessage",
                getFirebaseErrorMessage(error),
                "error"
            );

            showToast(
                "La création du compte a rencontré un problème.",
                "error"
            );

        } finally {

            if (submitButton) {
                submitButton.disabled = false;

                submitButton.textContent =
                    "Créer mon compte et envoyer ma candidature";
            }

        }

    });
}


// ============================================================
// TRADUCTION DES ERREURS FIREBASE
// ============================================================

function getFirebaseErrorMessage(error) {

    console.error(error);

    const code = error?.code || "";

    switch (code) {

        case "auth/email-already-in-use":
            return "Cette adresse email possède déjà un compte.";

        case "auth/invalid-email":
            return "L'adresse email n'est pas valide.";

        case "auth/weak-password":
            return "Le mot de passe est trop faible.";

        case "auth/network-request-failed":
            return "Connexion Internet impossible. Vérifie ta connexion.";

        case "auth/operation-not-allowed":
            return "La connexion par email/mot de passe n'est pas activée dans Firebase Authentication.";

        case "permission-denied":
            return "Firebase a refusé cette opération. Vérifie les règles Firestore.";

        case "failed-precondition":
            return "Firebase demande une configuration supplémentaire.";

        case "unavailable":
            return "Le service Firebase est temporairement indisponible.";

        default:

            if (error?.message) {
                return `Erreur : ${error.message}`;
            }

            return "Une erreur inconnue s'est produite.";
    }
}


// ============================================================
// AUTHENTIFICATION — UTILISATEUR CONNECTÉ
// ============================================================

function setupAuthenticationListener() {

    if (!auth) {
        return;
    }

    onAuthStateChanged(auth, async user => {

        if (!user) {

            hideElement("userBar");

            hideElement("publishButton");

            return;
        }


        console.log(
            "Utilisateur connecté :",
            user.email
        );


        showElement("userBar");


        try {

            const userReference =
                doc(db, "users", user.uid);

            const userSnapshot =
                await getDoc(userReference);


            if (userSnapshot.exists()) {

                const profile =
                    userSnapshot.data();


                const name =
                    `${profile.prenom || ""} ${profile.nom || ""}`.trim();


                $("currentUserName").textContent =
                    name || user.email;


                $("currentUserRole").textContent =
                    profile.role || "Member";


                const publishingRoles = [
                    "technicien",
                    "researcher",
                    "educator",
                    "developer",
                    "responsible",
                    "admin",
                    "super_admin"
                ];


                if (
                    publishingRoles.includes(
                        profile.role
                    )
                ) {

                    showElement("publishButton");

                }

            }

            loadNotifications(user.uid);

        } catch (error) {

            console.error(
                "Erreur chargement profil :",
                error
            );

        }

    });
}


// ============================================================
// PUBLICATIONS — MUR DU CAMPUS
// ============================================================

function loadPublications() {

    if (!db) {
        return;
    }

    const feed = $("campusFeed");

    if (!feed) {
        return;
    }


    const publicationsQuery =
        query(
            collection(db, "publications"),
            orderBy("date", "desc"),
            limit(30)
        );


    onSnapshot(
        publicationsQuery,

        snapshot => {

            feed.innerHTML = "";


            if (snapshot.empty) {

                feed.innerHTML = `
                    <div class="empty-state">
                        Aucune publication pour le moment.
                    </div>
                `;

                return;
            }


            snapshot.forEach(documentSnapshot => {

                const publication =
                    documentSnapshot.data();

                const card =
                    createPublicationCard(
                        documentSnapshot.id,
                        publication
                    );

                feed.appendChild(card);

            });

        },

        error => {

            console.error(
                "Erreur chargement publications :",
                error
            );

            feed.innerHTML = `
                <div class="empty-state">
                    Impossible de charger le Mur du Campus pour le moment.
                </div>
            `;

        }
    );
}


// ============================================================
// CARTE PUBLICATION
// ============================================================

function createPublicationCard(id, publication) {

    const article =
        document.createElement("article");

    article.className =
        "publication-card";


    const type =
        publication.type || "annonce";


    const author =
        publication.author_name ||
        "DeepRDMMakademy";


    const role =
        publication.author_role ||
        "Campus";


    const content =
        publication.contenu ||
        "";


    const pinned =
        publication.pinned === true;


    article.innerHTML = `

        <div class="publication-header">

            <div>
                <strong>${escapeHtml(author)}</strong>

                <small>
                    ${escapeHtml(role)}
                </small>
            </div>

            ${
                pinned
                    ? `<span class="publication-pinned">📌 ÉPINGLÉ</span>`
                    : ""
            }

        </div>


        <div class="publication-type">
            ${formatPublicationType(type)}
        </div>


        <div class="publication-content">
            ${escapeHtml(content)}
        </div>


        ${
            publication.image
                ? `
                    <img
                        class="publication-image"
                        src="${escapeAttribute(publication.image)}"
                        alt="Publication DeepRDMMakademy"
                    >
                  `
                : ""
        }


        <div class="publication-actions">

            <button
                type="button"
                class="reaction-button"
                data-publication="${id}"
                data-reaction="likes_count"
            >
                👍
                <span>${publication.likes_count || 0}</span>
            </button>


            <button
                type="button"
                class="reaction-button"
                data-publication="${id}"
                data-reaction="super_count"
            >
                ⭐
                <span>${publication.super_count || 0}</span>
            </button>


            <button
                type="button"
                class="reaction-button"
                data-publication="${id}"
                data-reaction="genial_count"
            >
                🚀
                <span>${publication.genial_count || 0}</span>
            </button>


            <button
                type="button"
                class="reaction-button"
                data-publication="${id}"
                data-reaction="utile_count"
            >
                💡
                <span>${publication.utile_count || 0}</span>
            </button>

        </div>

    `;


    article
        .querySelectorAll(".reaction-button")
        .forEach(button => {

            button.addEventListener(
                "click",
                () => {

                    handleReaction(
                        button.dataset.publication,
                        button.dataset.reaction
                    );

                }
            );

        });


    return article;
}


// ============================================================
// RÉACTIONS
// ============================================================

async function handleReaction(
    publicationId,
    reactionField
) {

    if (!auth?.currentUser) {

        showToast(
            "Connecte-toi pour réagir à une publication.",
            "error"
        );

        return;
    }


    const allowedFields = [
        "likes_count",
        "super_count",
        "genial_count",
        "utile_count"
    ];


    if (!allowedFields.includes(reactionField)) {
        return;
    }


    try {

        await updateDoc(
            doc(db, "publications", publicationId),
            {
                [reactionField]:
                    increment(1)
            }
        );

    } catch (error) {

        console.error(
            "Erreur réaction :",
            error
        );

        showToast(
            "Impossible d'enregistrer la réaction.",
            "error"
        );

    }
}


// ============================================================
// PUBLICATION PAR STAFF
// ============================================================

function setupPublicationInterface() {

    const publishButton =
        $("publishButton");

    const publisher =
        $("adminPublisher");

    const closePublisher =
        $("closePublisher");

    const submitPublication =
        $("submitPublication");


    if (publishButton && publisher) {

        publishButton.addEventListener(
            "click",
            () => {
                showElement("adminPublisher");
            }
        );

    }


    if (closePublisher) {

        closePublisher.addEventListener(
            "click",
            () => {
                hideElement("adminPublisher");
            }
        );

    }


    if (submitPublication) {

        submitPublication.addEventListener(
            "click",
            publishCampusAnnouncement
        );

    }

}


async function publishCampusAnnouncement() {

    if (!auth?.currentUser) {

        showToast(
            "Tu dois être connecté.",
            "error"
        );

        return;
    }


    const type =
        $("publicationType")?.value;

    const content =
        $("publicationContent")?.value.trim();


    if (!content) {

        showToast(
            "Écris un message avant de publier.",
            "error"
        );

        return;
    }


    try {

        const profileSnapshot =
            await getDoc(
                doc(
                    db,
                    "users",
                    auth.currentUser.uid
                )
            );


        if (!profileSnapshot.exists()) {

            showToast(
                "Profil utilisateur introuvable.",
                "error"
            );

            return;
        }


        const profile =
            profileSnapshot.data();


        const publishingRoles = [
            "technicien",
            "researcher",
            "educator",
            "developer",
            "responsible",
            "admin",
            "super_admin"
        ];


        if (!publishingRoles.includes(profile.role)) {

            showToast(
                "Ton rôle ne permet pas encore de publier.",
                "error"
            );

            return;
        }


        await addDoc(
            collection(db, "publications"),
            {
                user_id: auth.currentUser.uid,

                author_name:
                    `${profile.prenom || ""} ${profile.nom || ""}`.trim(),

                author_role:
                    profile.role || "Member",

                type: type,

                contenu: content,

                image: "",

                pinned: false,

                likes_count: 0,
                super_count: 0,
                genial_count: 0,
                utile_count: 0,

                date: serverTimestamp()
            }
        );


        $("publicationContent").value = "";

        hideElement("adminPublisher");

        showToast(
            "Publication envoyée sur le Mur du Campus.",
            "success"
        );


    } catch (error) {

        console.error(
            "Erreur publication :",
            error
        );

        showToast(
            getFirebaseErrorMessage(error),
            "error"
        );

    }
}


// ============================================================
// NOTIFICATIONS
// ============================================================

function loadNotifications(userId) {

    if (!db || !userId) {
        return;
    }


    const notificationQuery =
        query(
            collection(db, "notifications"),
            where("user_id", "==", userId),
            orderBy("date", "desc"),
            limit(30)
        );


    onSnapshot(
        notificationQuery,

        snapshot => {

            const list =
                $("notificationList");

            const badge =
                $("notificationBadge");


            if (!list || !badge) {
                return;
            }


            list.innerHTML = "";


            let unreadCount = 0;


            snapshot.forEach(documentSnapshot => {

                const notification =
                    documentSnapshot.data();


                if (
                    notification.lu_ou_non !== true
                ) {
                    unreadCount++;
                }


                const item =
                    document.createElement("div");

                item.className =
                    "notification-item";


                item.innerHTML = `

                    <strong>
                        ${escapeHtml(
                            notification.message || "Notification"
                        )}
                    </strong>

                    ${
                        notification.lien
                            ? `
                                <a href="${escapeAttribute(notification.lien)}">
                                    Ouvrir
                                </a>
                              `
                            : ""
                    }

                `;


                item.addEventListener(
                    "click",
                    () => {

                        markNotificationRead(
                            documentSnapshot.id
                        );

                    }
                );


                list.appendChild(item);

            });


            if (unreadCount > 0) {

                badge.textContent =
                    unreadCount;

                badge.classList.remove(
                    "hidden"
                );

            } else {

                badge.textContent = "0";

                badge.classList.add(
                    "hidden"
                );

            }

        },

        error => {

            console.error(
                "Erreur notifications :",
                error
            );

        }
    );
}


async function markNotificationRead(
    notificationId
) {

    if (!auth?.currentUser) {
        return;
    }


    try {

        await updateDoc(
            doc(
                db,
                "notifications",
                notificationId
            ),
            {
                lu_ou_non: true
            }
        );

    } catch (error) {

        console.error(
            "Erreur notification :",
            error
        );

    }
}


function setupNotificationPanel() {

    const button =
        $("notificationButton");

    const panel =
        $("notificationPanel");

    const markAll =
        $("markNotificationsRead");


    if (button && panel) {

        button.addEventListener(
            "click",
            () => {

                panel.classList.toggle(
                    "hidden"
                );

            }
        );

    }


    if (markAll) {

        markAll.addEventListener(
            "click",
            async () => {

                if (!auth?.currentUser) {
                    return;
                }

                showToast(
                    "Les notifications seront marquées comme lues.",
                    "info"
                );

            }
        );

    }

}


// ============================================================
// COMPTEURS CAMPUS
// ============================================================

function loadMemberCount() {

    if (!db) {
        return;
    }


    const memberCount =
        $("memberCount");


    if (!memberCount) {
        return;
    }


    const usersQuery =
        query(
            collection(db, "users"),
            where("status", "==", "active"),
            limit(1000)
        );


    onSnapshot(
        usersQuery,

        snapshot => {

            memberCount.textContent =
                snapshot.size;

        },

        error => {

            console.error(
                "Erreur compteur membres :",
                error
            );

            memberCount.textContent =
                "--";

        }
    );

}


// ============================================================
// COMPTEUR MISSIONS
// ============================================================

function loadMissionCount() {

    if (!db) {
        return;
    }


    const missionCount =
        $("missionCount");


    if (!missionCount) {
        return;
    }


    // Les missions seront connectées à leur collection
    // officielle lorsque le moteur des missions sera installé.

    missionCount.textContent = "--";
}


// ============================================================
// MISSIONS
// ============================================================

function loadMissions() {

    const container =
        $("missionsContainer");


    if (!container) {
        return;
    }


    // Première version : aucune mission réelle publiée.

    container.innerHTML = `

        <article class="mission-card">

            <span class="mission-status">
                EN PRÉPARATION
            </span>

            <h3>
                Prochaine mission scientifique
            </h3>

            <p>
                Les prochaines missions seront publiées
                depuis le Campus DeepRDMMakademy.
            </p>

        </article>

    `;
}


// ============================================================
// SÉCURITÉ HTML
// ============================================================

function escapeHtml(value) {

    return String(value ?? "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}


function escapeAttribute(value) {

    return escapeHtml(value);
}


// ============================================================
// TYPE PUBLICATION
// ============================================================

function formatPublicationType(type) {

    const labels = {

        nouvelle_mission:
            "🚀 NOUVELLE MISSION",

        resultat_concours:
            "🏆 RÉSULTAT CONCOURS",

        panne_paillasse:
            "⚠️ PANNE PAILLASSE",

        annonce:
            "📢 ANNONCE"

    };


    return labels[type] ||
        "📢 CAMPUS";
}


// ============================================================
// INITIALISATION DE L'APPLICATION
// ============================================================

function initializeDeepRDM() {

    console.log(
        "DeepRDMMakademy — Initialisation..."
    );


    setupModalButtons();

    setupFollowForm();

    setupMemberForm();

    setupAuthenticationListener();

    setupPublicationInterface();

    setupNotificationPanel();

    loadPublications();

    loadMemberCount();

    loadMissionCount();

    loadMissions();


    console.log(
        "DeepRDMMakademy — Interface prête."
    );
}


// ============================================================
// DÉMARRAGE
// ============================================================

if (
    document.readyState === "loading"
) {

    document.addEventListener(
        "DOMContentLoaded",
        initializeDeepRDM
    );

} else {

    initializeDeepRDM();

}
