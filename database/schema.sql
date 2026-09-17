/* ============================================================
   DEEPRDMMAKADEMY
   DATABASE SCHEMA — INTERNATIONAL EDUCATION PLATFORM
   ============================================================

   Architecture générale :

   UTILISATEURS
       ↓
   PROFILS / RÔLES
       ↓
   NIVEAUX ÉDUCATIFS
       ↓
   FILIÈRES
       ↓
   SPÉCIALISATIONS
       ↓
   PROGRAMMES
       ↓
   MATIÈRES
       ↓
   CHAPITRES
       ↓
   LEÇONS
       ↓
   COMPÉTENCES
       ↓
   EXERCICES / QUESTIONS
       ↓
   ÉVALUATIONS
       ↓
   VALIDATION
       ↓
   PROGRESSION

   Architecture prévue pour :
   - plusieurs pays
   - plusieurs systèmes éducatifs
   - plusieurs langues
   - plusieurs filières
   - plusieurs niveaux
   - enseignement classique
   - formation professionnelle
   - enseignement supérieur
   - recherche
   - communauté
   - paiements futurs

   Compatible MySQL / MariaDB.
   ============================================================ */


/* ============================================================
   1. USERS
   ============================================================ */

CREATE TABLE IF NOT EXISTS users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    uuid CHAR(36) NOT NULL UNIQUE,

    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,

    email VARCHAR(255) NOT NULL UNIQUE,

    password_hash VARCHAR(255) NOT NULL,

    phone VARCHAR(50) NULL,
    country_code CHAR(2) NULL,
    preferred_language VARCHAR(10) NOT NULL DEFAULT 'fr',

    status VARCHAR(30) NOT NULL DEFAULT 'active',

    email_verified_at DATETIME NULL,

    requested_level VARCHAR(100) NULL,
    recommended_level VARCHAR(100) NULL,
    validated_level VARCHAR(100) NULL,
    current_level VARCHAR(100) NULL,

    class_group VARCHAR(100) NULL,

    last_login_at DATETIME NULL,
    last_activity_at DATETIME NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_users_email (email),
    INDEX idx_users_status (status),
    INDEX idx_users_country (country_code),
    INDEX idx_users_language (preferred_language),
    INDEX idx_users_current_level (current_level)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;


/* ============================================================
   2. ROLES
   ============================================================ */

CREATE TABLE IF NOT EXISTS roles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;


/* ============================================================
   3. DEFAULT ROLES
   ============================================================ */

INSERT IGNORE INTO roles (code, name, description) VALUES
('visitor', 'Visitor', 'Utilisateur non connecté'),
('candidate', 'Candidate', 'Candidat à l''inscription ou à un programme'),
('student', 'Student', 'Élève ou étudiant'),
('member', 'Member', 'Membre de la communauté'),
('researcher', 'Researcher', 'Chercheur'),
('educator', 'Educator', 'Enseignant ou formateur'),
('developer', 'Developer', 'Développeur autorisé sur certains espaces de travail'),
('responsible', 'Responsible', 'Responsable d''un espace ou d''une équipe'),
('admin', 'Administrator', 'Administrateur'),
('super_admin', 'Super Administrator', 'Administrateur principal');


/* ============================================================
   4. USER ROLES
   ============================================================ */

CREATE TABLE IF NOT EXISTS user_roles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    user_id BIGINT UNSIGNED NOT NULL,
    role_id BIGINT UNSIGNED NOT NULL,

    assigned_by BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_user_role (user_id, role_id),

    CONSTRAINT fk_user_roles_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_user_roles_role
        FOREIGN KEY (role_id)
        REFERENCES roles(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_user_roles_assigned_by
        FOREIGN KEY (assigned_by)
        REFERENCES users(id)
        ON DELETE SET NULL
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;


/* ============================================================
   5. LOGIN ATTEMPTS
   ============================================================ */

CREATE TABLE IF NOT EXISTS login_attempts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    email VARCHAR(255) NULL,
    user_id BIGINT UNSIGNED NULL,

    ip_address VARCHAR(45) NULL,
    user_agent TEXT NULL,

    success TINYINT(1) NOT NULL DEFAULT 0,

    attempted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_login_email (email),
    INDEX idx_login_user (user_id),
    INDEX idx_login_ip (ip_address),
    INDEX idx_login_time (attempted_at),

    CONSTRAINT fk_login_attempt_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE SET NULL
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;


/* ============================================================
   6. SESSIONS
   ============================================================ */

CREATE TABLE IF NOT EXISTS sessions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    user_id BIGINT UNSIGNED NOT NULL,

    session_token_hash VARCHAR(255) NOT NULL UNIQUE,

    ip_address VARCHAR(45) NULL,
    user_agent TEXT NULL,

    expires_at DATETIME NOT NULL,
    last_seen_at DATETIME NULL,

    revoked_at DATETIME NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_sessions_user (user_id),
    INDEX idx_sessions_expiry (expires_at),

    CONSTRAINT fk_sessions_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;


/* ============================================================
   7. AUDIT LOGS
   ============================================================ */

CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    user_id BIGINT UNSIGNED NULL,

    action VARCHAR(150) NOT NULL,
    entity_type VARCHAR(100) NULL,
    entity_id BIGINT UNSIGNED NULL,

    ip_address VARCHAR(45) NULL,
    user_agent TEXT NULL,

    details JSON NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_audit_user (user_id),
    INDEX idx_audit_action (action),
    INDEX idx_audit_entity (entity_type, entity_id),
    INDEX idx_audit_date (created_at),

    CONSTRAINT fk_audit_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE SET NULL
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;


/* ============================================================
   8. EDUCATION LEVELS
   ============================================================ */

CREATE TABLE IF NOT EXISTS education_levels (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,

    stage VARCHAR(100) NOT NULL,

    sequence_number INT NOT NULL DEFAULT 0,

    description TEXT NULL,

    is_active TINYINT(1) NOT NULL DEFAULT 1,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_levels_stage (stage),
    INDEX idx_levels_sequence (sequence_number)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;


/* ============================================================
   9. BASE EDUCATION LEVELS
   ============================================================ */

INSERT IGNORE INTO education_levels
(code, name, stage, sequence_number, description)
VALUES

/* Préscolaire */
('PS', 'Petite Section', 'Preschool', 10, 'Premier niveau préscolaire'),
('MS', 'Moyenne Section', 'Preschool', 20, 'Deuxième niveau préscolaire'),
('GS', 'Grande Section', 'Preschool', 30, 'Troisième niveau préscolaire'),

/* Primaire */
('CP1', 'Cours Préparatoire 1', 'Primary', 40, 'Début du primaire'),
('CP2', 'Cours Préparatoire 2', 'Primary', 50, 'Deuxième année du primaire'),
('CE1', 'Cours Élémentaire 1', 'Primary', 60, 'Troisième année du primaire'),
('CE2', 'Cours Élémentaire 2', 'Primary', 70, 'Quatrième année du primaire'),
('CM1', 'Cours Moyen 1', 'Primary', 80, 'Cinquième année du primaire'),
('CM2', 'Cours Moyen 2', 'Primary', 90, 'Sixième année du primaire'),

/* Collège */
('6E', 'Sixième', 'Middle School', 100, 'Premier niveau du collège'),
('5E', 'Cinquième', 'Middle School', 110, 'Deuxième niveau du collège'),
('4E', 'Quatrième', 'Middle School', 120, 'Troisième niveau du collège'),
('3E', 'Troisième', 'Middle School', 130, 'Dernier niveau du collège'),

/* Lycée */
('2NDE', 'Seconde', 'High School', 140, 'Premier niveau du lycée'),
('1ERE', 'Première', 'High School', 150, 'Deuxième niveau du lycée'),
('TERMINALE', 'Terminale', 'High School', 160, 'Dernier niveau du lycée'),

/* Université */
('L1', 'Licence 1', 'Undergraduate', 170, 'Première année universitaire'),
('L2', 'Licence 2', 'Undergraduate', 180, 'Deuxième année universitaire'),
('L3', 'Licence 3', 'Undergraduate', 190, 'Troisième année universitaire'),

/* Master */
('M1', 'Master 1', 'Graduate', 200, 'Première année de master'),
('M2', 'Master 2', 'Graduate', 210, 'Deuxième année de master'),

/* Extension future */
('D1', 'Doctorat 1', 'Doctorate', 220, 'Première étape du doctorat'),
('D2', 'Doctorat 2', 'Doctorate', 230, 'Deuxième étape du doctorat'),
('D3', 'Doctorat 3', 'Doctorate', 240, 'Troisième étape du doctorat'),

/* Formation professionnelle */
('PRO1', 'Formation Professionnelle 1', 'Professional', 250, 'Formation professionnelle'),
('PRO2', 'Formation Professionnelle 2', 'Professional', 260, 'Formation professionnelle avancée'),
('PRO3', 'Formation Professionnelle 3', 'Professional', 270, 'Formation professionnelle spécialisée');


/* ============================================================
   10. EDUCATION FIELDS
   ============================================================ */

CREATE TABLE IF NOT EXISTS education_fields (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    code VARCHAR(80) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,

    description TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_fields_name (name)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;


/* ============================================================
   11. MAJOR INTERNATIONAL FIELDS
   ============================================================ */

INSERT IGNORE INTO education_fields
(code, name, description)
VALUES

('GENERAL', 'Enseignement général',
 'Socle général et disciplines fondamentales'),

('SCIENCES', 'Sciences',
 'Sciences naturelles et sciences fondamentales'),

('MATHEMATICS', 'Mathématiques',
 'Mathématiques fondamentales et appliquées'),

('PHYSICS', 'Physique',
 'Physique fondamentale et appliquée'),

('CHEMISTRY', 'Chimie',
 'Chimie fondamentale et appliquée'),

('BIOLOGY', 'Biologie',
 'Sciences biologiques'),

('MEDICINE', 'Médecine et santé',
 'Médecine et sciences de la santé'),

('PHARMACY', 'Pharmacie',
 'Sciences pharmaceutiques'),

('DENTISTRY', 'Odontologie',
 'Médecine dentaire'),

('NURSING', 'Soins infirmiers',
 'Sciences infirmières et soins'),

('BIOMEDICAL', 'Sciences biomédicales',
 'Sciences biomédicales'),

('COMPUTER_SCIENCE', 'Informatique',
 'Informatique et sciences computationnelles'),

('ARTIFICIAL_INTELLIGENCE', 'Intelligence artificielle',
 'IA et systèmes intelligents'),

('DATA_SCIENCE', 'Data Science',
 'Données, statistiques et analyse'),

('CYBERSECURITY', 'Cybersécurité',
 'Sécurité informatique et réseaux'),

('ENGINEERING', 'Ingénierie',
 'Sciences de l''ingénieur'),

('SOFTWARE_ENGINEERING', 'Génie logiciel',
 'Conception et développement logiciel'),

('ELECTRICAL_ENGINEERING', 'Génie électrique',
 'Électricité, électronique et systèmes'),

('MECHANICAL_ENGINEERING', 'Génie mécanique',
 'Mécanique et systèmes industriels'),

('CIVIL_ENGINEERING', 'Génie civil',
 'Construction et infrastructures'),

('CHEMICAL_ENGINEERING', 'Génie chimique',
 'Procédés et industrie chimique'),

('ARCHITECTURE', 'Architecture',
 'Architecture, construction et conception'),

('AGRICULTURE', 'Agriculture',
 'Sciences agricoles'),

('ENVIRONMENT', 'Environnement',
 'Sciences environnementales'),

('EARTH_SCIENCE', 'Sciences de la Terre',
 'Géologie, géophysique et disciplines associées'),

('ASTRONOMY', 'Astronomie et espace',
 'Astronomie, astrophysique et sciences spatiales'),

('ECONOMICS', 'Économie',
 'Sciences économiques'),

('BUSINESS', 'Gestion et management',
 'Management, gestion et organisation'),

('COMMERCE', 'Commerce',
 'Commerce et activités commerciales'),

('FINANCE', 'Finance',
 'Finance et marchés'),

('ACCOUNTING', 'Comptabilité',
 'Comptabilité et audit'),

('MARKETING', 'Marketing',
 'Marketing et stratégie commerciale'),

('LAW', 'Droit',
 'Sciences juridiques'),

('POLITICAL_SCIENCE', 'Sciences politiques',
 'Politique et institutions'),

('INTERNATIONAL_RELATIONS', 'Relations internationales',
 'Relations internationales et géopolitique'),

('SOCIOLOGY', 'Sociologie',
 'Étude des sociétés'),

('PSYCHOLOGY', 'Psychologie',
 'Sciences psychologiques'),

('PHILOSOPHY', 'Philosophie',
 'Philosophie et pensée critique'),

('HISTORY', 'Histoire',
 'Sciences historiques'),

('GEOGRAPHY', 'Géographie',
 'Sciences géographiques'),

('HUMANITIES', 'Sciences humaines',
 'Humanités et sciences humaines'),

('LANGUAGES', 'Langues',
 'Langues, linguistique et littérature'),

('LITERATURE', 'Littérature',
 'Littérature et études littéraires'),

('COMMUNICATION', 'Communication',
 'Communication et médias'),

('JOURNALISM', 'Journalisme',
 'Journalisme et médias'),

('EDUCATION', 'Sciences de l''éducation',
 'Pédagogie et éducation'),

('ARTS', 'Arts',
 'Arts et pratiques artistiques'),

('DESIGN', 'Design',
 'Design graphique, produit et numérique'),

('MUSIC', 'Musique',
 'Études musicales'),

('FILM', 'Cinéma et audiovisuel',
 'Production audiovisuelle'),

('SPORT', 'Sport et activité physique',
 'Sciences du sport'),

('TOURISM', 'Tourisme',
 'Tourisme et hôtellerie'),

('HOSPITALITY', 'Hôtellerie',
 'Hôtellerie et restauration'),

('TRANSPORT', 'Transport et logistique',
 'Transport, logistique et supply chain'),

('MARITIME', 'Sciences maritimes',
 'Navigation et sciences maritimes'),

('AVIATION', 'Aviation',
 'Aéronautique et aviation'),

('SOCIAL_WORK', 'Travail social',
 'Travail social et accompagnement'),

('RELIGION_CULTURE', 'Culture et études religieuses',
 'Culture, histoire des religions et patrimoine');


/* ============================================================
   12. SPECIALIZATIONS
   ============================================================ */

CREATE TABLE IF NOT EXISTS specializations (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    field_id BIGINT UNSIGNED NOT NULL,

    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL,

    description TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_specializations_field (field_id),

    CONSTRAINT fk_specialization_field
        FOREIGN KEY (field_id)
        REFERENCES education_fields(id)
        ON DELETE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;


/* ============================================================
   13. COMPUTER SCIENCE SPECIALIZATIONS
   ============================================================ */

INSERT IGNORE INTO specializations
(field_id, code, name, description)
SELECT
    id,
    'DEV_WEB',
    'Développement Web',
    'Développement frontend, backend et full stack'
FROM education_fields
WHERE code = 'COMPUTER_SCIENCE';

INSERT IGNORE INTO specializations
(field_id, code, name, description)
SELECT
    id,
    'DEV_MOBILE',
    'Développement Mobile',
    'Applications mobiles Android et iOS'
FROM education_fields
WHERE code = 'COMPUTER_SCIENCE';

INSERT IGNORE INTO specializations
(field_id, code, name, description)
SELECT
    id,
    'SOFTWARE_ENGINEERING',
    'Software Engineering',
    'Architecture et ingénierie logicielle'
FROM education_fields
WHERE code = 'SOFTWARE_ENGINEERING';

INSERT IGNORE INTO specializations
(field_id, code, name, description)
SELECT
    id,
    'NETWORK_ENGINEERING',
    'Réseaux',
    'Réseaux informatiques et infrastructures'
FROM education_fields
WHERE code = 'COMPUTER_SCIENCE';

INSERT IGNORE INTO specializations
(field_id, code, name, description)
SELECT
    id,
    'CYBERSECURITY_ENGINEERING',
    'Cybersécurité',
    'Sécurité des systèmes et infrastructures'
FROM education_fields
WHERE code = 'CYBERSECURITY';

INSERT IGNORE INTO specializations
(field_id, code, name, description)
SELECT
    id,
    'DATA_SCIENCE',
    'Data Science',
    'Analyse et modélisation des données'
FROM education_fields
WHERE code = 'DATA_SCIENCE';

INSERT IGNORE INTO specializations
(field_id, code, name, description)
SELECT
    id,
    'MACHINE_LEARNING',
    'Machine Learning',
    'Apprentissage automatique'
FROM education_fields
WHERE code = 'ARTIFICIAL_INTELLIGENCE';

INSERT IGNORE INTO specializations
(field_id, code, name, description)
SELECT
    id,
    'DEEP_LEARNING',
    'Deep Learning',
    'Réseaux neuronaux et apprentissage profond'
FROM education_fields
WHERE code = 'ARTIFICIAL_INTELLIGENCE';

INSERT IGNORE INTO specializations
(field_id, code, name, description)
SELECT
    id,
    'COMPUTER_VISION',
    'Computer Vision',
    'Vision artificielle et traitement d''images'
FROM education_fields
WHERE code = 'ARTIFICIAL_INTELLIGENCE';

INSERT IGNORE INTO specializations
(field_id, code, name, description)
SELECT
    id,
    'NLP',
    'Natural Language Processing',
    'Traitement automatique du langage'
FROM education_fields
WHERE code = 'ARTIFICIAL_INTELLIGENCE';


/* ============================================================
   14. SUBJECTS
   ============================================================ */

CREATE TABLE IF NOT EXISTS subjects (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL,

    field_id BIGINT UNSIGNED NULL,

    description TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_subject_field (field_id),

    CONSTRAINT fk_subject_field
        FOREIGN KEY (field_id)
        REFERENCES education_fields(id)
        ON DELETE SET NULL
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;


/* ============================================================
   15. CORE SUBJECT CATALOG
   ============================================================ */

INSERT IGNORE INTO subjects
(code, name, description)
VALUES

/* Sciences */
('MATHEMATICS', 'Mathématiques', 'Mathématiques'),
('ALGEBRA', 'Algèbre', 'Algèbre'),
('GEOMETRY', 'Géométrie', 'Géométrie'),
('CALCULUS', 'Calcul différentiel et intégral', 'Calcul avancé'),
('STATISTICS', 'Statistiques', 'Statistiques'),
('PROBABILITY', 'Probabilités', 'Probabilités'),
('PHYSICS', 'Physique', 'Physique'),
('CHEMISTRY', 'Chimie', 'Chimie'),
('BIOLOGY', 'Biologie', 'Biologie'),
('SVT', 'Sciences de la Vie et de la Terre', 'SVT'),
('ASTRONOMY', 'Astronomie', 'Astronomie'),
('ASTROPHYSICS', 'Astrophysique', 'Astrophysique'),
('GEOLOGY', 'Géologie', 'Géologie'),
('GEOPHYSICS', 'Géophysique', 'Géophysique'),

/* Langues */
('FRENCH', 'Français', 'Langue française'),
('ENGLISH', 'English', 'Langue anglaise'),
('MALAGASY', 'Malagasy', 'Langue malgache'),
('SPANISH', 'Espagnol', 'Langue espagnole'),
('GERMAN', 'Allemand', 'Langue allemande'),
('ITALIAN', 'Italien', 'Langue italienne'),
('
