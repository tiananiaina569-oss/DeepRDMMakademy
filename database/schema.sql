-- ============================================================
-- DEEPRDMMAKADEMY
-- BASE DE DONNÉES CENTRALE
-- ============================================================
--
-- Architecture :
-- Authentification
-- Membres
-- Rôles / permissions
-- Sessions / sécurité
-- Audit
-- Éducation internationale
-- Profils étudiants
-- Placement
-- Niveaux
-- Changements de niveau
-- Domaines / spécialités
-- Matières
-- Programmes
-- Chapitres
-- Leçons
-- Compétences
-- Questions
-- Exercices
-- Évaluations
--
-- Langues initiales :
-- Français / Malagasy / English
--
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;


-- ============================================================
-- 1. USERS
-- ============================================================

DROP TABLE IF EXISTS users;

CREATE TABLE users (
    id CHAR(36) NOT NULL,

    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,

    email VARCHAR(190) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'active',

    account_type VARCHAR(30) NOT NULL DEFAULT 'member',

    preferred_language VARCHAR(10) NOT NULL DEFAULT 'fr',

    country_code VARCHAR(10) NULL,

    email_verified_at DATETIME NULL,

    last_login_at DATETIME NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at DATETIME NOT NULL
        DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    UNIQUE KEY uq_users_email (email),

    KEY idx_users_status (status),

    KEY idx_users_account_type (account_type),

    KEY idx_users_country (country_code)

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 2. ROLES
-- ============================================================

DROP TABLE IF EXISTS roles;

CREATE TABLE roles (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,

    name VARCHAR(100) NOT NULL,

    slug VARCHAR(100) NOT NULL,

    description TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    UNIQUE KEY uq_roles_slug (slug)

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 3. USER ROLES
-- ============================================================

DROP TABLE IF EXISTS user_roles;

CREATE TABLE user_roles (
    user_id CHAR(36) NOT NULL,

    role_id INT UNSIGNED NOT NULL,

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

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 4. LOGIN ATTEMPTS
-- ============================================================

DROP TABLE IF EXISTS login_attempts;

CREATE TABLE login_attempts (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    user_id CHAR(36) NULL,

    email VARCHAR(190) NULL,

    ip_address VARCHAR(45) NULL,

    success TINYINT(1) NOT NULL DEFAULT 0,

    attempted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    KEY idx_login_email_time (
        email,
        attempted_at
    ),

    KEY idx_login_ip_time (
        ip_address,
        attempted_at
    ),

    CONSTRAINT fk_login_attempts_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE SET NULL

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 5. SESSIONS
-- ============================================================

DROP TABLE IF EXISTS sessions;

CREATE TABLE sessions (
    id CHAR(36) NOT NULL,

    user_id CHAR(36) NOT NULL,

    token_hash CHAR(64) NOT NULL,

    ip_address VARCHAR(45) NULL,

    user_agent TEXT NULL,

    expires_at DATETIME NOT NULL,

    revoked_at DATETIME NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    last_used_at DATETIME NULL,

    PRIMARY KEY (id),

    UNIQUE KEY uq_sessions_token_hash (
        token_hash
    ),

    KEY idx_sessions_user (
        user_id
    ),

    KEY idx_sessions_expires (
        expires_at
    ),

    CONSTRAINT fk_sessions_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 6. AUDIT LOGS
-- ============================================================

DROP TABLE IF EXISTS audit_logs;

CREATE TABLE audit_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    user_id CHAR(36) NULL,

    action VARCHAR(150) NOT NULL,

    entity_type VARCHAR(100) NULL,

    entity_id VARCHAR(100) NULL,

    ip_address VARCHAR(45) NULL,

    details JSON NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    KEY idx_audit_user (
        user_id
    ),

    KEY idx_audit_action (
        action
    ),

    KEY idx_audit_created (
        created_at
    ),

    CONSTRAINT fk_audit_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE SET NULL

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 7. COUNTRIES
-- ============================================================

DROP TABLE IF EXISTS countries;

CREATE TABLE countries (
    code VARCHAR(10) NOT NULL,

    name VARCHAR(150) NOT NULL,

    active TINYINT(1) NOT NULL DEFAULT 1,

    PRIMARY KEY (code)

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 8. EDUCATION LANGUAGES
-- ============================================================

DROP TABLE IF EXISTS education_languages;

CREATE TABLE education_languages (
    code VARCHAR(10) NOT NULL,

    name VARCHAR(100) NOT NULL,

    native_name VARCHAR(100) NULL,

    active TINYINT(1) NOT NULL DEFAULT 1,

    PRIMARY KEY (code)

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 9. CURRICULUM SYSTEMS
-- ============================================================

DROP TABLE IF EXISTS curriculum_systems;

CREATE TABLE curriculum_systems (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,

    country_code VARCHAR(10) NULL,

    code VARCHAR(100) NOT NULL,

    name VARCHAR(200) NOT NULL,

    description TEXT NULL,

    active TINYINT(1) NOT NULL DEFAULT 1,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    UNIQUE KEY uq_curriculum_code (code),

    KEY idx_curriculum_country (country_code),

    CONSTRAINT fk_curriculum_country
        FOREIGN KEY (country_code)
        REFERENCES countries(code)
        ON DELETE SET NULL

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 10. EDUCATION LEVELS
-- ============================================================

DROP TABLE IF EXISTS education_levels;

CREATE TABLE education_levels (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,

    curriculum_system_id INT UNSIGNED NULL,

    code VARCHAR(50) NOT NULL,

    name VARCHAR(150) NOT NULL,

    level_order INT NOT NULL,

    stage VARCHAR(50) NOT NULL,

    description TEXT NULL,

    active TINYINT(1) NOT NULL DEFAULT 1,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    UNIQUE KEY uq_education_level_code (
        curriculum_system_id,
        code
    ),

    KEY idx_education_level_order (
        level_order
    ),

    KEY idx_education_level_stage (
        stage
    ),

    CONSTRAINT fk_education_level_curriculum
        FOREIGN KEY (curriculum_system_id)
        REFERENCES curriculum_systems(id)
        ON DELETE SET NULL

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 11. EDUCATION FIELDS
-- ============================================================

DROP TABLE IF EXISTS education_fields;

CREATE TABLE education_fields (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,

    code VARCHAR(100) NOT NULL,

    name VARCHAR(200) NOT NULL,

    description TEXT NULL,

    active TINYINT(1) NOT NULL DEFAULT 1,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    UNIQUE KEY uq_education_field_code (
        code
    )

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 12. SPECIALIZATIONS
-- ============================================================

DROP TABLE IF EXISTS specializations;

CREATE TABLE specializations (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,

    field_id INT UNSIGNED NULL,

    code VARCHAR(100) NOT NULL,

    name VARCHAR(200) NOT NULL,

    description TEXT NULL,

    active TINYINT(1) NOT NULL DEFAULT 1,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    UNIQUE KEY uq_specialization_code (
        code
    ),

    KEY idx_specialization_field (
        field_id
    ),

    CONSTRAINT fk_specialization_field
        FOREIGN KEY (field_id)
        REFERENCES education_fields(id)
        ON DELETE SET NULL

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 13. STUDENT PROFILES
-- ============================================================
--
-- requested_level :
-- Niveau demandé par l'étudiant.
--
-- recommended_level :
-- Niveau recommandé après le placement.
--
-- validated_level :
-- Niveau officiellement validé.
--
-- current_level :
-- Niveau actuellement utilisé dans le parcours.
--
-- L'IA peut recommander.
-- L'autorité pédagogique valide.
--
-- ============================================================

DROP TABLE IF EXISTS student_profiles;

CREATE TABLE student_profiles (
    id CHAR(36) NOT NULL,

    user_id CHAR(36) NOT NULL,

    country_code VARCHAR(10) NULL,

    curriculum_system_id INT UNSIGNED NULL,

    instruction_language VARCHAR(10) NOT NULL DEFAULT 'fr',

    education_stage VARCHAR(50) NULL,

    requested_level VARCHAR(100) NULL,

    recommended_level VARCHAR(100) NULL,

    validated_level VARCHAR(100) NULL,

    current_level VARCHAR(100) NULL,

    education_field_id INT UNSIGNED NULL,

    specialization_id INT UNSIGNED NULL,

    learning_goal VARCHAR(100) NULL,

    placement_status VARCHAR(40) NOT NULL DEFAULT 'not_started',

    placement_started_at DATETIME NULL,

    placement_completed_at DATETIME NULL,

    placement_score DECIMAL(6,2) NULL,

    validated_at DATETIME NULL,

    validated_by CHAR(36) NULL,

    profile_version INT NOT NULL DEFAULT 1,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    UNIQUE KEY uq_student_profile_user (
        user_id
    ),

    KEY idx_student_country (
        country_code
    ),

    KEY idx_student_curriculum (
        curriculum_system_id
    ),

    KEY idx_student_language (
        instruction_language
    ),

    KEY idx_student_requested_level (
        requested_level
    ),

    KEY idx_student_recommended_level (
        recommended_level
    ),

    KEY idx_student_validated_level (
        validated_level
    ),

    KEY idx_student_current_level (
        current_level
    ),

    KEY idx_student_placement_status (
        placement_status
    ),

    CONSTRAINT fk_student_profile_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_student_profile_country
        FOREIGN KEY (country_code)
        REFERENCES countries(code)
        ON DELETE SET NULL,

    CONSTRAINT fk_student_profile_curriculum
        FOREIGN KEY (curriculum_system_id)
        REFERENCES curriculum_systems(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_student_profile_language
        FOREIGN KEY (instruction_language)
        REFERENCES education_languages(code)
        ON DELETE RESTRICT,

    CONSTRAINT fk_student_profile_field
        FOREIGN KEY (education_field_id)
        REFERENCES education_fields(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_student_profile_specialization
        FOREIGN KEY (specialization_id)
        REFERENCES specializations(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_student_profile_validator
        FOREIGN KEY (validated_by)
        REFERENCES users(id)
        ON DELETE SET NULL

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 14. STUDENT LEVEL HISTORY
-- ============================================================

DROP TABLE IF EXISTS student_level_history;

CREATE TABLE student_level_history (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    student_profile_id CHAR(36) NOT NULL,

    previous_level VARCHAR(100) NULL,

    new_level VARCHAR(100) NOT NULL,

    change_type VARCHAR(50) NOT NULL,

    reason TEXT NULL,

    source VARCHAR(50) NOT NULL DEFAULT 'system',

    changed_by CHAR(36) NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    KEY idx_level_history_profile (
        student_profile_id
    ),

    KEY idx_level_history_date (
        created_at
    ),

    CONSTRAINT fk_level_history_profile
        FOREIGN KEY (student_profile_id)
        REFERENCES student_profiles(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_level_history_user
        FOREIGN KEY (changed_by)
        REFERENCES users(id)
        ON DELETE SET NULL

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 15. STUDENT LEVEL CHANGE REQUESTS
-- ============================================================

DROP TABLE IF EXISTS student_level_change_requests;

CREATE TABLE student_level_change_requests (
    id CHAR(36) NOT NULL,

    student_profile_id CHAR(36) NOT NULL,

    requested_by CHAR(36) NOT NULL,

    current_level VARCHAR(100) NULL,

    requested_level VARCHAR(100) NOT NULL,

    recommended_level VARCHAR(100) NULL,

    status VARCHAR(40) NOT NULL DEFAULT 'pending',

    reason TEXT NULL,

    assessment_required TINYINT(1) NOT NULL DEFAULT 1,

    assessment_completed TINYINT(1) NOT NULL DEFAULT 0,

    reviewed_by CHAR(36) NULL,

    reviewed_at DATETIME NULL,

    decision_note TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    KEY idx_level_request_profile (
        student_profile_id
    ),

    KEY idx_level_request_user (
        requested_by
    ),

    KEY idx_level_request_status (
        status
    ),

    CONSTRAINT fk_level_request_profile
        FOREIGN KEY (student_profile_id)
        REFERENCES student_profiles(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_level_request_user
        FOREIGN KEY (requested_by)
        REFERENCES users(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_level_request_reviewer
        FOREIGN KEY (reviewed_by)
        REFERENCES users(id)
        ON DELETE SET NULL

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 16. SUBJECTS
-- ============================================================

DROP TABLE IF EXISTS subjects;

CREATE TABLE subjects (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,

    field_id INT UNSIGNED NULL,

    code VARCHAR(100) NOT NULL,

    name VARCHAR(200) NOT NULL,

    description TEXT NULL,

    active TINYINT(1) NOT NULL DEFAULT 1,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    UNIQUE KEY uq_subject_code (
        code
    ),

    KEY idx_subject_field (
        field_id
    ),

    CONSTRAINT fk_subject_field
        FOREIGN KEY (field_id)
        REFERENCES education_fields(id)
        ON DELETE SET NULL

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 17. LEVEL SUBJECTS
-- ============================================================

DROP TABLE IF EXISTS level_subjects;

CREATE TABLE level_subjects (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    level_id INT UNSIGNED NOT NULL,

    subject_id INT UNSIGNED NOT NULL,

    mandatory TINYINT(1) NOT NULL DEFAULT 1,

    coefficient DECIMAL(6,2) NOT NULL DEFAULT 1.00,

    sequence_order INT NOT NULL DEFAULT 1,

    PRIMARY KEY (id),

    UNIQUE KEY uq_level_subject (
        level_id,
        subject_id
    ),

    CONSTRAINT fk_level_subject_level
        FOREIGN KEY (level_id)
        REFERENCES education_levels(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_level_subject_subject
        FOREIGN KEY (subject_id)
        REFERENCES subjects(id)
        ON DELETE CASCADE

) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 18. PROGRAMS
-- ============================================================

DROP TABLE IF EXISTS programs;

CREATE TABLE programs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    level_id INT UNSIGNED NULL,

    field_id INT UNSIGNED NULL,

    specialization_id INT UNSIGNED NULL,

    code VARCHAR(100) NOT NULL,

    name VARCHAR(250) NOT NULL,

    description LONGTEXT NULL,

    language_code VARCHAR(10) NOT NULL DEFAULT 'fr',

    duration_months INT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'draft',

    generation_source VARCHAR(50) NOT NULL DEFAULT 'system',

    generated_by_ai TINYINT(1) NOT NULL DEFAULT 1,

    generated_at DATETIME NULL,

    created_by CHAR(36) NULL,

    validated_by CHAR(36) NULL,

    version INT NOT NULL DEFAULT 1,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    UNIQUE KEY uq_program_code_language (
        code,
        language_code
    ),

    KEY idx_program_level (
        level_id
    ),

    KEY idx_program_field (
        field_id
    ),

    CONSTRAINT fk_program_level
        FOREIGN KEY (level_id)
        REFERENCES education_levels(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_program_field
        FOREIGN KEY (field_id)
        REFERENCES education_fields(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_program_specialization
        FOREIGN KEY (specialization_id)
        REFERENCES specializations(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_program_language
        FOREIGN KEY (language_code)
        REFERENCES education_languages(code)
        ON DELETE RESTRICT,

    CONSTRAINT fk_program_creator
        FOREIGN KEY (created_by)
        REFERENCES users(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_program_validator
     
