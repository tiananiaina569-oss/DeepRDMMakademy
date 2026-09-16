/* ============================================================
   DEEPRDMMAKADEMY
   BASE DE DONNÉES COMPLÈTE
   Authentification + Architecture pédagogique
   Préscolaire → Primaire → Collège → Lycée → Université → Master
   ============================================================ */

CREATE DATABASE IF NOT EXISTS deeprdmmakademy
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE deeprdmmakademy;


/* ============================================================
   1. UTILISATEURS
   ============================================================ */

CREATE TABLE users (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL,

    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(190) NOT NULL,

    country VARCHAR(100) DEFAULT NULL,
    current_level VARCHAR(100) DEFAULT NULL,
    class_group VARCHAR(100) DEFAULT NULL,

    password_hash VARCHAR(255) NOT NULL,

    status ENUM(
        'pending',
        'active',
        'suspended',
        'inactive',
        'deleted'
    ) NOT NULL DEFAULT 'active',

    requested_level VARCHAR(100) DEFAULT NULL,
    recommended_level VARCHAR(100) DEFAULT NULL,
    validated_level VARCHAR(100) DEFAULT NULL,

    email_verified_at DATETIME DEFAULT NULL,
    last_login_at DATETIME DEFAULT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    UNIQUE KEY uq_users_uuid (uuid),
    UNIQUE KEY uq_users_email (email),
    KEY idx_users_status (status),
    KEY idx_users_level (current_level),
    KEY idx_users_class (class_group)
) ENGINE=InnoDB;


/* ============================================================
   2. RÔLES
   ============================================================ */

CREATE TABLE roles (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL,
    description VARCHAR(255) DEFAULT NULL,

    PRIMARY KEY (id),
    UNIQUE KEY uq_roles_name (name)
) ENGINE=InnoDB;

INSERT INTO roles (name, description) VALUES
('visitor', 'Visiteur non authentifié'),
('candidate', 'Candidat en attente de validation'),
('student', 'Étudiant'),
('member', 'Membre'),
('researcher', 'Chercheur'),
('educator', 'Éducateur'),
('developer', 'Développeur'),
('responsible', 'Responsable'),
('admin', 'Administrateur'),
('super_admin', 'Super administrateur');


/* ============================================================
   3. RELATION UTILISATEURS / RÔLES
   ============================================================ */

CREATE TABLE user_roles (
    user_id BIGINT UNSIGNED NOT NULL,
    role_id BIGINT UNSIGNED NOT NULL,

    assigned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (user_id, role_id),

    CONSTRAINT fk_user_roles_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_user_roles_role
        FOREIGN KEY (role_id)
        REFERENCES roles(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;


/* ============================================================
   4. TENTATIVES DE CONNEXION
   ============================================================ */

CREATE TABLE login_attempts (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    email VARCHAR(190) NOT NULL,
    ip_address VARCHAR(45) DEFAULT NULL,

    attempted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    successful TINYINT(1) NOT NULL DEFAULT 0,

    PRIMARY KEY (id),
    KEY idx_login_email (email),
    KEY idx_login_time (attempted_at)
) ENGINE=InnoDB;


/* ============================================================
   5. SESSIONS
   ============================================================ */

CREATE TABLE sessions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    user_id BIGINT UNSIGNED NOT NULL,
    session_token_hash CHAR(64) NOT NULL,

    ip_address VARCHAR(45) DEFAULT NULL,
    user_agent TEXT DEFAULT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NOT NULL,
    last_activity_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    UNIQUE KEY uq_session_token (session_token_hash),
    KEY idx_sessions_user (user_id),
    KEY idx_sessions_expiry (expires_at),

    CONSTRAINT fk_sessions_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;


/* ============================================================
   6. JOURNAL D'AUDIT
   ============================================================ */

CREATE TABLE audit_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    user_id BIGINT UNSIGNED DEFAULT NULL,

    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100) DEFAULT NULL,
    entity_id BIGINT UNSIGNED DEFAULT NULL,

    ip_address VARCHAR(45) DEFAULT NULL,
    details JSON DEFAULT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    KEY idx_audit_user (user_id),
    KEY idx_audit_action (action),
    KEY idx_audit_date (created_at),

    CONSTRAINT fk_audit_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE SET NULL
) ENGINE=InnoDB;


/* ============================================================
   7. NIVEAUX D'ÉDUCATION
   ============================================================ */

CREATE TABLE education_levels (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    code VARCHAR(50) NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT DEFAULT NULL,

    education_stage ENUM(
        'preschool',
        'primary',
        'middle_school',
        'high_school',
        'university',
        'master'
    ) NOT NULL,

    sort_order INT NOT NULL DEFAULT 0,
    is_active TINYINT(1) NOT NULL DEFAULT 1,

    PRIMARY KEY (id),
    UNIQUE KEY uq_education_level_code (code),
    KEY idx_education_stage (education_stage),
    KEY idx_education_order (sort_order)
) ENGINE=InnoDB;

INSERT INTO education_levels
(code, name, description, education_stage, sort_order)
VALUES

/* PRÉSCOLAIRE */
('PS', 'Petite Section', 'Éveil et premières découvertes.', 'preschool', 10),
('MS', 'Moyenne Section', 'Développement des compétences fondamentales.', 'preschool', 20),
('GS', 'Grande Section', 'Préparation à l''entrée au primaire.', 'preschool', 30),

/* PRIMAIRE */
('CP1', 'Cours Préparatoire 1', 'Première année du primaire.', 'primary', 40),
('CP2', 'Cours Préparatoire 2', 'Deuxième année du primaire.', 'primary', 50),
('CE1', 'Cours Élémentaire 1', 'Troisième année du primaire.', 'primary', 60),
('CE2', 'Cours Élémentaire 2', 'Quatrième année du primaire.', 'primary', 70),
('CM1', 'Cours Moyen 1', 'Cinquième année du primaire.', 'primary', 80),
('CM2', 'Cours Moyen 2', 'Sixième année du primaire.', 'primary', 90),

/* COLLÈGE */
('6E', 'Sixième', 'Première année du collège.', 'middle_school', 100),
('5E', 'Cinquième', 'Deuxième année du collège.', 'middle_school', 110),
('4E', 'Quatrième', 'Troisième année du collège.', 'middle_school', 120),
('3E', 'Troisième', 'Fin du collège.', 'middle_school', 130),

/* LYCÉE */
('2NDE', 'Seconde', 'Première année du lycée.', 'high_school', 140),
('1ERE', 'Première', 'Deuxième année du lycée.', 'high_school', 150),
('TERMINALE', 'Terminale', 'Année de préparation au baccalauréat.', 'high_school', 160),

/* UNIVERSITÉ */
('L1', 'Licence 1', 'Première année universitaire.', 'university', 170),
('L2', 'Licence 2', 'Deuxième année universitaire.', 'university', 180),
('L3', 'Licence 3', 'Troisième année universitaire.', 'university', 190),

/* MASTER */
('M1', 'Master 1', 'Première année de Master.', 'master', 200),
('M2', 'Master 2', 'Deuxième année de Master.', 'master', 210);


/* ============================================================
   8. FILIÈRES
   ============================================================ */

CREATE TABLE fields (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    code VARCHAR(50) NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT DEFAULT NULL,

    education_stage ENUM(
        'general',
        'technical',
        'professional',
        'university',
        'master'
    ) NOT NULL DEFAULT 'general',

    icon VARCHAR(100) DEFAULT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    is_active TINYINT(1) NOT NULL DEFAULT 1,

    PRIMARY KEY (id),
    UNIQUE KEY uq_field_code (code),
    KEY idx_field_stage (education_stage)
) ENGINE=InnoDB;


/* ============================================================
   9. FILIÈRES PRINCIPALES
   ============================================================ */

INSERT INTO fields
(code, name, description, education_stage, sort_order)
VALUES

('GENERAL', 'Enseignement général',
 'Formation générale et fondamentale.',
 'general', 10),

('SCIENCES', 'Sciences',
 'Mathématiques, physique, chimie, sciences de la vie et de la Terre.',
 'general', 20),

('LETTRES', 'Lettres et langues',
 'Français, langues, littérature, philosophie et sciences humaines.',
 'general', 30),

('HUMANITIES', 'Sciences humaines',
 'Histoire, géographie, sociologie, psychologie et disciplines associées.',
 'general', 40),

('ECONOMIE', 'Économie et gestion',
 'Économie, gestion, finance, comptabilité et commerce.',
 'general', 50),

('DROIT', 'Droit',
 'Droit et sciences juridiques.',
 'university', 60),

('INFORMATIQUE', 'Informatique',
 'Informatique, programmation, systèmes et technologies numériques.',
 'university', 70),

('IA', 'Intelligence artificielle',
 'Intelligence artificielle, machine learning et science des données.',
 'university', 80),

('INGENIERIE', 'Sciences de l''ingénieur',
 'Ingénierie et technologies.',
 'university', 90),

('MEDECINE', 'Médecine et santé',
 'Sciences médicales et disciplines de santé.',
 'university', 100),

('PHARMACIE', 'Pharmacie',
 'Sciences pharmaceutiques.',
 'university', 110),

('BIOLOGIE', 'Biologie',
 'Biologie, microbiologie et sciences du vivant.',
 'university', 120),

('CHIMIE', 'Chimie',
 'Chimie fondamentale et appliquée.',
 'university', 130),

('PHYSIQUE', 'Physique',
 'Physique fondamentale et appliquée.',
 'university', 140),

('MATHEMATIQUES', 'Mathématiques',
 'Mathématiques fondamentales et appliquées.',
 'university', 150),

('ARCHITECTURE', 'Architecture',
 'Architecture, urbanisme et construction.',
 'university', 160),

('AGRONOMIE', 'Agronomie',
 'Agriculture, agronomie et sciences environnementales.',
 'university', 170),

('ENVIRONNEMENT', 'Environnement',
 'Sciences environnementales et développement durable.',
 'university', 180),

('COMMUNICATION', 'Communication et médias',
 'Communication, médias, journalisme et relations publiques.',
 'university', 190),

('ARTS', 'Arts et design',
 'Arts, design, création numérique et audiovisuel.',
 'university', 200),

('EDUCATION', 'Sciences de l''éducation',
 'Pédagogie, enseignement et formation.',
 'university', 210),

('TOURISME', 'Tourisme et hôtellerie',
 'Tourisme, hôtellerie et gestion touristique.',
 'university', 220),

('COMMERCE', 'Commerce et marketing',
 'Commerce, marketing et développement commercial.',
 'university', 230),

('TRANSPORT', 'Transport et logistique',
 'Transport, logistique et supply chain.',
 'university', 240),

('SCIENCES_POLITIQUES', 'Sciences politiques',
 'Politique, relations internationales et administration.',
 'university', 250),

('SOCIOLOGIE', 'Sociologie',
 'Étude des sociétés et des phénomènes sociaux.',
 'university', 260),

('PSYCHOLOGIE', 'Psychologie',
 'Étude du comportement et des processus mentaux.',
 'university', 270);


/* ============================================================
   10. SPÉCIALITÉS / DOMAINES UNIVERSITAIRES
   ============================================================ */

CREATE TABLE specializations (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    field_id BIGINT UNSIGNED NOT NULL,

    code VARCHAR(80) NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT DEFAULT NULL,

    PRIMARY KEY (id),
    UNIQUE KEY uq_specialization_code (code),
    KEY idx_specialization_field (field_id),

    CONSTRAINT fk_specialization_field
        FOREIGN KEY (field_id)
        REFERENCES fields(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;


/* ============================================================
   11. SPÉCIALITÉS INFORMATIQUES
   ============================================================ */

INSERT INTO specializations
(field_id, code, name, description)
SELECT
    id,
    'DEV_WEB',
    'Développement Web',
    'HTML, CSS, JavaScript, PHP, bases de données et applications web.'
FROM fields WHERE code = 'INFORMATIQUE';

INSERT INTO specializations
(field_id, code, name, description)
SELECT
    id,
    'DEV_MOBILE',
    'Développement Mobile',
    'Création d''applications mobiles Android et iOS.'
FROM fields WHERE code = 'INFORMATIQUE';

INSERT INTO specializations
(field_id, code, name, description)
SELECT
    id,
    'CYBERSECURITY',
    'Cybersécurité',
    'Sécurité informatique, réseaux, systèmes et protection des données.'
FROM fields WHERE code = 'INFORMATIQUE';

INSERT INTO specializations
(field_id, code, name, description)
SELECT
    id,
    'DATA_SCIENCE',
    'Data Science',
    'Analyse de données, statistiques et science des données.'
FROM fields WHERE code = 'INFORMATIQUE';

INSERT INTO specializations
(field_id, code, name, description)
SELECT
    id,
    'SOFTWARE_ENGINEERING',
    'Génie logiciel',
    'Conception, développement et maintenance de logiciels.'
FROM fields WHERE code = 'INFORMATIQUE';


/* ============================================================
   12. SPÉCIALITÉS IA
   ============================================================ */

INSERT INTO specializations
(field_id, code, name, description)
SELECT
    id,
    'MACHINE_LEARNING',
    'Machine Learning',
    'Apprentissage automatique et modèles prédictifs.'
FROM fields WHERE code = 'IA';

INSERT INTO specializations
(field_id, code, name, description)
SELECT
    id,
    'DEEP_LEARNING',
    'Deep Learning',
    'Réseaux neuronaux et apprentissage profond.'
FROM fields WHERE code = 'IA';

INSERT INTO specializations
(field_id, code, name, description)
SELECT
    id,
    'COMPUTER_VISION',
    'Vision par ordinateur',
    'Analyse et compréhension des images et vidéos.'
FROM fields WHERE code = 'IA';

INSERT INTO specializations
(field_id, code, name, description)
SELECT
    id,
    'NLP',
    'Traitement du langage naturel',
    'Compréhension et génération automatique du langage.'
FROM fields WHERE code = 'IA';


/* ============================================================
   13. MATIÈRES
   ============================================================ */

CREATE TABLE subjects (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    code VARCHAR(80) NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT DEFAULT NULL,

    category VARCHAR(100) DEFAULT NULL,

    PRIMARY KEY (id),
    UNIQUE KEY uq_subject_code (code),
    KEY idx_subject_category (category)
) ENGINE=InnoDB;


/* ============================================================
   14. MATIÈRES FONDAMENTALES
   ============================================================ */

INSERT INTO subjects
(code, name, description, category)
VALUES

('MATH', 'Mathématiques',
 'Nombres, calcul, géométrie, algèbre, analyse et probabilités.',
 'Sciences'),

('PHYSICS', 'Physique',
 'Mécanique, énergie, électricité, optique et physique moderne.',
 'Sciences'),

('CHEMISTRY', 'Chimie',
 'Structure de la matière, réactions chimiques et chimie appliquée.',
 'Sciences'),

('BIOLOGY', 'Sciences de la vie et biologie',
 'Étude du vivant et des organismes.',
 'Sciences'),

('SVT', 'Sciences de la Vie et de la Terre',
 'Biologie, géologie, environnement et sciences de la Terre.',
 'Sciences'),

('FRENCH', 'Français',
 'Langue française, expression, grammaire et littérature.',
 'Langues'),

('ENGLISH', 'Anglais',
 'Langue anglaise et communication.',
 'Langues'),

('MALAGASY', 'Malagasy',
 'Langue et culture malgaches.',
 'Langues'),

('SPANISH', 'Espagnol',
 'Langue espagnole et civilisation.',
 'Langues'),

('GERMAN', 'Allemand',
 'Langue allemande et civilisation.',
 'Langues'),

('HISTORY', 'Histoire',
 'Étude des sociétés et événements historiques.',
 'Sciences humaines'),

('GEOGRAPHY', 'Géographie',
 'Territoires, populations, environnement et espaces.',
 'Sciences humaines'),

('PHILOSOPHY', 'Philosophie',
 'Réflexion critique, logique et pensée philosophique.',
 'Sciences humaines'),

('ECONOMICS', 'Économie',
 'Principes économiques et fonctionnement des marchés.',
 'Économie'),

('ACCOUNTING', 'Comptabilité',
 'Principes comptables et gestion financière.',
 'Gestion'),

('BUSINESS', 'Gestion',
 'Management, organisation et gestion des entreprises.',
 'Gestion'),

('MARKETING', 'Marketing',
 'Stratégie commerciale, communication et comportement du consommateur.',
 'Commerce'),

('LAW', 'Droit',
 'Principes juridiques et institutions.',
 'Droit'),

('COMPUTER_SCIENCE', 'Informatique',
 'Algorithmique, programmation et systèmes informatiques.',
 'Technologie'),

('PROGRAMMING', 'Programmation',
 'Développement de logiciels et applications.',
 'Technologie'),

('ALGORITHM', 'Algorithmique',
 'Conception et analyse des algorithmes.',
 'Technologie'),

('DATABASE', 'Bases de données',
 'Modélisation, SQL et systèmes de gestion de bases de données.',
 'Technologie'),

('NETWORK', 'Réseaux informatiques',
 'Communication entre systèmes et infrastructures réseau.',
 'Technologie'),

('CYBERSECURITY', 'Cybersécurité',
 'Protection des systèmes, réseaux et données.',
 'Technologie'),

('AI', 'Intelligence artificielle',
 'Concepts et applications de l''intelligence artificielle.',
 'Technologie'),

('DATA_SCIENCE', 'Science des données',
 'Statistiques, données et analyse.',
 'Technologie'),

('ART', 'Arts plastiques',
 'Expression artistique et créativité.',
 'Arts'),

('MUSIC', 'Musique',
 'Théorie musicale, pratique et culture musicale.',
 'Arts'),

('PHYSICAL_EDUCATION', 'Éducation physique et sportive',
 'Activité physique, sport et santé.',
 'Sport'),

('CIVIC_EDUCATION', 'Éducation civique',
 'Citoyenneté, société et responsabilités.',
 'Citoyenneté'),

('RELIGION_CULTURE', 'Culture et société',
 'Culture, valeurs et société.',
 'Culture'),

('TECHNOLOGY', 'Technologie',
 'Technologies, conception et applications techniques.',
 'Technologie'),

('ENGINEERING', 'Sciences de l''ingénieur',
 'Conception et analyse des systèmes techniques.',
 'Ingénierie'),

('AGRICULTURE', 'Agriculture',
 'Production agricole et sciences agronomiques.',
 'Agronomie'),

('ENVIRONMENT', 'Environnement',
 'Protection de l''environnement et développement durable.',
 'Environnement'),

('PSYCHOLOGY', 'Psychologie',
 'Étude du comportement et des processus mentaux.',
 'Sciences humaines'),

('SOCIOLOGY', 'Sociologie',
 'Étude des sociétés et des relations sociales.',
 'Sciences humaines'),

('COMMUNICATION', 'Communication',
 'Communication interpersonnelle, professionnelle et médiatique.',
 'Communication');


/* ============================================================
   15. ASSOCIATION NIVEAUX / MATIÈRES
   ============================================================ */

CREATE TABLE level_subjects (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    level_id BIGINT UNSIGNED NOT NULL,
    subject_id BIGINT UNSIGNED NOT NULL,

    coefficient DECIMAL(5,2) DEFAULT 1.00,
    is_required TINYINT(1) NOT NULL DEFAULT 1,

    PRIMARY KEY (id),

    UNIQUE KEY uq_level_subject (level_id, subject_id),

    CONSTRAINT fk_level_subject_level
        FOREIGN KEY (level_id)
        REFERENCES education_levels(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_level_subject_subject
        FOREIGN KEY (subject_id)
        REFERENCES subjects(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;


/* ============================================================
   16. PROGRAMMES
   ===============================================
