-- ============================================================
-- DeepRDMMakademy
-- DATABASE FOUNDATION
-- PHP 8.x + MySQL / MariaDB
-- ============================================================
-- IMPORTANT:
-- Sélectionner la base de données DeepRDMMakademy dans
-- phpMyAdmin avant d'importer ce fichier.
--
-- Ce fichier ne contient volontairement ni CREATE DATABASE
-- ni USE.
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================
-- 1. USERS / SECURITY
-- ============================================================

DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS admin_actions;
DROP TABLE IF EXISTS account_departures;
DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS login_attempts;
DROP TABLE IF EXISTS user_roles;
DROP TABLE IF EXISTS roles;
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
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    UNIQUE KEY uq_users_email (email),
    KEY idx_users_status (status),
    KEY idx_users_account_type (account_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE roles (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL,
    description TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    UNIQUE KEY uq_roles_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE user_roles (
    user_id CHAR(36) NOT NULL,
    role_id INT UNSIGNED NOT NULL,
    assigned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (user_id, role_id),

    CONSTRAINT fk_user_roles_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_user_roles_role
        FOREIGN KEY (role_id) REFERENCES roles(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE login_attempts (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id CHAR(36) NULL,
    email VARCHAR(190) NULL,
    ip_address VARCHAR(45) NULL,
    success TINYINT(1) NOT NULL DEFAULT 0,
    attempted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    KEY idx_login_email_time (email, attempted_at),
    KEY idx_login_ip_time (ip_address, attempted_at),

    CONSTRAINT fk_login_attempts_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


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
    UNIQUE KEY uq_sessions_token_hash (token_hash),
    KEY idx_sessions_user (user_id),
    KEY idx_sessions_expires (expires_at),

    CONSTRAINT fk_sessions_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


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
    KEY idx_audit_user (user_id),
    KEY idx_audit_action (action),
    KEY idx_audit_created (created_at),

    CONSTRAINT fk_audit_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 2. INTERNATIONAL EDUCATION STRUCTURE
-- ============================================================

DROP TABLE IF EXISTS curriculum_systems;
DROP TABLE IF EXISTS countries;
DROP TABLE IF EXISTS education_languages;
DROP TABLE IF EXISTS education_levels;
DROP TABLE IF EXISTS education_fields;

CREATE TABLE countries (
    code VARCHAR(10) NOT NULL,
    name VARCHAR(150) NOT NULL,

    PRIMARY KEY (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE education_languages (
    code VARCHAR(10) NOT NULL,
    name VARCHAR(100) NOT NULL,
    native_name VARCHAR(100) NULL,
    active TINYINT(1) NOT NULL DEFAULT 1,

    PRIMARY KEY (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE curriculum_systems (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    country_code VARCHAR(10) NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT NULL,
    active TINYINT(1) NOT NULL DEFAULT 1,

    PRIMARY KEY (id),

    CONSTRAINT fk_curriculum_country
        FOREIGN KEY (country_code) REFERENCES countries(code)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE education_levels (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,

    code VARCHAR(50) NOT NULL,
    name VARCHAR(150) NOT NULL,
    level_order INT NOT NULL,

    stage VARCHAR(50) NULL,
    description TEXT NULL,

    curriculum_system_id INT UNSIGNED NULL,

    active TINYINT(1) NOT NULL DEFAULT 1,

    PRIMARY KEY (id),
    UNIQUE KEY uq_education_levels_code (code),
    KEY idx_level_order (level_order),

    CONSTRAINT fk_level_curriculum
        FOREIGN KEY (curriculum_system_id)
        REFERENCES curriculum_systems(id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE education_fields (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,

    code VARCHAR(100) NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT NULL,

    active TINYINT(1) NOT NULL DEFAULT 1,

    PRIMARY KEY (id),
    UNIQUE KEY uq_fields_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 3. SPECIALIZATIONS
-- ============================================================

DROP TABLE IF EXISTS specializations;

CREATE TABLE specializations (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    field_id INT UNSIGNED NULL,

    code VARCHAR(100) NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT NULL,

    active TINYINT(1) NOT NULL DEFAULT 1,

    PRIMARY KEY (id),
    UNIQUE KEY uq_specialization_code (code),

    CONSTRAINT fk_specialization_field
        FOREIGN KEY (field_id) REFERENCES education_fields(id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 4. SUBJECTS
-- ============================================================

DROP TABLE IF EXISTS level_subjects;
DROP TABLE IF EXISTS subjects;

CREATE TABLE subjects (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,

    field_id INT UNSIGNED NULL,

    code VARCHAR(100) NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    active TINYINT(1) NOT NULL DEFAULT 1,

    PRIMARY KEY (id),
    UNIQUE KEY uq_subject_code (code),

    CONSTRAINT fk_subject_field
        FOREIGN KEY (field_id) REFERENCES education_fields(id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE level_subjects (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    level_id INT UNSIGNED NOT NULL,
    subject_id INT UNSIGNED NOT NULL,

    mandatory TINYINT(1) NOT NULL DEFAULT 1,
    coefficient DECIMAL(6,2) NOT NULL DEFAULT 1.00,

    PRIMARY KEY (id),
    UNIQUE KEY uq_level_subject (level_id, subject_id),

    CONSTRAINT fk_level_subject_level
        FOREIGN KEY (level_id) REFERENCES education_levels(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_level_subject_subject
        FOREIGN KEY (subject_id) REFERENCES subjects(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 5. PROGRAMS
-- ============================================================

DROP TABLE IF EXISTS program_subjects;
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
    generated_at DATETIME NULL,

    created_by CHAR(36) NULL,
    validated_by CHAR(36) NULL,

    version INT NOT NULL DEFAULT 1,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    UNIQUE KEY uq_program_code_language (code, language_code),

    CONSTRAINT fk_program_level
        FOREIGN KEY (level_id) REFERENCES education_levels(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_program_field
        FOREIGN KEY (field_id) REFERENCES education_fields(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_program_specialization
        FOREIGN KEY (specialization_id) REFERENCES specializations(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_program_creator
        FOREIGN KEY (created_by) REFERENCES users(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_program_validator
        FOREIGN KEY (validated_by) REFERENCES users(id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE program_subjects (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    program_id BIGINT UNSIGNED NOT NULL,
    subject_id INT UNSIGNED NOT NULL,

    sequence_order INT NOT NULL DEFAULT 1,
    weekly_hours DECIMAL(6,2) NULL,
    coefficient DECIMAL(6,2) NOT NULL DEFAULT 1.00,

    PRIMARY KEY (id),
    UNIQUE KEY uq_program_subject (program_id, subject_id),

    CONSTRAINT fk_program_subject_program
        FOREIGN KEY (program_id) REFERENCES programs(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_program_subject_subject
        FOREIGN KEY (subject_id) REFERENCES subjects(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 6. CHAPTERS / LESSONS
-- ============================================================

DROP TABLE IF EXISTS lesson_competencies;
DROP TABLE IF EXISTS lesson_prerequisites;
DROP TABLE IF EXISTS lessons;
DROP TABLE IF EXISTS chapters;

CREATE TABLE chapters (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    program_id BIGINT UNSIGNED NULL,
    subject_id INT UNSIGNED NOT NULL,

    title VARCHAR(250) NOT NULL,
    description LONGTEXT NULL,

    sequence_order INT NOT NULL DEFAULT 1,

    status VARCHAR(30) NOT NULL DEFAULT 'published',

    language_code VARCHAR(10) NOT NULL DEFAULT 'fr',

    generated_by_ai TINYINT(1) NOT NULL DEFAULT 1,

    version INT NOT NULL DEFAULT 1,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    CONSTRAINT fk_chapter_program
        FOREIGN KEY (program_id) REFERENCES programs(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_chapter_subject
        FOREIGN KEY (subject_id) REFERENCES subjects(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE lessons (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    chapter_id BIGINT UNSIGNED NOT NULL,

    title VARCHAR(250) NOT NULL,
    summary TEXT NULL,

    objective LONGTEXT NULL,
    discovery_content LONGTEXT NULL,
    examples LONGTEXT NULL,
    guided_practice LONGTEXT NULL,
    independent_practice LONGTEXT NULL,
    mini_quiz LONGTEXT NULL,
    validation_content LONGTEXT NULL,

    estimated_minutes INT NOT NULL DEFAULT 45,

    sequence_order INT NOT NULL DEFAULT 1,

    status VARCHAR(30) NOT NULL DEFAULT 'published',

    language_code VARCHAR(10) NOT NULL DEFAULT 'fr',

    generated_by_ai TINYINT(1) NOT NULL DEFAULT 1,

    version INT NOT NULL DEFAULT 1,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    CONSTRAINT fk_lesson_chapter
        FOREIGN KEY (chapter_id) REFERENCES chapters(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE lesson_prerequisites (
    lesson_id BIGINT UNSIGNED NOT NULL,
    prerequisite_lesson_id BIGINT UNSIGNED NOT NULL,

    PRIMARY KEY (lesson_id, prerequisite_lesson_id),

    CONSTRAINT fk_lesson_prereq_lesson
        FOREIGN KEY (lesson_id) REFERENCES lessons(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_lesson_prereq_required
        FOREIGN KEY (prerequisite_lesson_id) REFERENCES lessons(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 7. COMPETENCIES
-- ============================================================

DROP TABLE IF EXISTS competency_prerequisites;
DROP TABLE IF EXISTS competencies;

CREATE TABLE competencies (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    subject_id INT UNSIGNED NULL,
    level_id INT UNSIGNED NULL,

    code VARCHAR(100) NOT NULL,
    name VARCHAR(250) NOT NULL,
    description LONGTEXT NULL,

    mastery_threshold DECIMAL(5,2) NOT NULL DEFAULT 70.00,

    active TINYINT(1) NOT NULL DEFAULT 1,

    PRIMARY KEY (id),
    UNIQUE KEY uq_competency_code (code),

    CONSTRAINT fk_competency_subject
        FOREIGN KEY (subject_id) REFERENCES subjects(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_competency_level
        FOREIGN KEY (level_id) REFERENCES education_levels(id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE lesson_competencies (
    lesson_id BIGINT UNSIGNED NOT NULL,
    competency_id BIGINT UNSIGNED NOT NULL,

    PRIMARY KEY (lesson_id, competency_id),

    CONSTRAINT fk_lesson_competency_lesson
        FOREIGN KEY (lesson_id) REFERENCES lessons(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_lesson_competency_competency
        FOREIGN KEY (competency_id) REFERENCES competencies(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE competency_prerequisites (
    competency_id BIGINT UNSIGNED NOT NULL,
    prerequisite_competency_id BIGINT UNSIGNED NOT NULL,

    PRIMARY KEY (competency_id, prerequisite_competency_id),

    CONSTRAINT fk_comp_prereq_comp
        FOREIGN KEY (competency_id) REFERENCES competencies(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_comp_prereq_required
        FOREIGN KEY (prerequisite_competency_id)
        REFERENCES competencies(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- 8. QUESTIONS / EXERCISES / EVALUATIONS
-- ============================================================

DROP TABLE IF EXISTS evaluation_attempt_answers;
DROP TABLE IF EXISTS evaluation_attempts;
DROP TABLE IF EXISTS evaluation_questions;
DROP TABLE IF EXISTS evaluations;
DROP TABLE IF EXISTS exercise_attempts;
DROP TABLE IF EXISTS exercises;
DROP TABLE IF EXISTS question_options;
DROP TABLE IF EXISTS questions;

CREATE TABLE questions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    subject_id INT UNSIGNED NULL,
    level_id INT UNSIGNED NULL,
    chapter_id BIGINT UNSIGNED NULL,
    competency_id BIGINT UNSIGNED NULL,

    question_text LONGTEXT NOT NULL,
    explanation LONGTEXT NULL,

    difficulty VARCHAR(30) NOT NULL DEFAULT 'medium',
    question_type VARCHAR(50) NOT NULL DEFAULT 'multiple_choice',

    correct_answer LONGTEXT NULL,

    language_code VARCHAR(10) NOT NULL DEFAULT 'fr',

    generated_by_ai TINYINT(1) NOT NULL DEFAULT 1,

    active TINYINT(1) NOT NULL DEFAULT 1,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    CONSTRAINT fk_question_subject
        FOREIGN KEY (subject_id) REFERENCES subjects(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_question_level
        FOREIGN KEY (level_id) REFERENCES education_levels(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_question_chapter
        FOREIGN KEY (chapter_id) REFERENCES chapters(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_question_competency
        FOREIGN KEY (competency_id) REFERENCES competencies(id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE question_options (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    question_id BIGINT UNSIGNED NOT NULL,

    option_key VARCHAR(20) NOT NULL,
    option_text LONGTEXT NOT NULL,

    PRIMARY KEY (id),
    UNIQUE KEY uq_question_option (question_id, option_key),

    CONSTRAINT fk_option_question
        FOREIGN KEY (question_id) REFERENCES questions(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE exercises (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    lesson_id BIGINT UNSIGNED NULL,
    subject_id INT UNSIGNED NULL,
    level_id INT UNSIGNED NULL,

    title VARCHAR(250) NOT NULL,
    instructions LONGTEXT NULL,

    difficulty VARCHAR(30) NOT NULL DEFAULT 'medium',

    generated_by_ai TINYINT(1) NOT NULL DEFAULT 1,

    status VARCHAR(30) NOT NULL DEFAULT 'published',

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    CONSTRAINT fk_exercise_lesson
        FOREIGN KEY (lesson_id) REFERENCES lessons(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_exercise_subject
        FOREIGN KEY (subject_id) REFERENCES subjects(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_exercise_level
        FOREIGN KEY (level_id) REFERENCES education_levels(id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE exercise_attempts (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    exercise_id BIGINT UNSIGNED NOT NULL,
    user_id CHAR(36) NOT NULL,

    answer_data JSON NULL,

    score DECIMAL(6,2) NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'submitted',

    started_at DATETIME NULL,
    submitted_at DATETIME NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    CONSTRAINT fk_exercise_attempt_exercise
        FOREIGN KEY (exercise_id) REFERENCES exercises(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_exercise_attempt_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE evaluations (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    program_id BIGINT UNSIGNED NULL,
    subject_id
