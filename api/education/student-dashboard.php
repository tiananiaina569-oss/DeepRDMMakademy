<?php

declare(strict_types=1);

/**
 * =========================================================
 * DeepRDMMakademy
 * Student Dashboard API
 * =========================================================
 *
 * Endpoint :
 * /api/education/student-dashboard.php
 *
 * Méthode :
 * GET
 *
 * Authentification :
 * Bearer Token
 *
 * Fonction :
 * Retourner les données officielles du compte étudiant :
 *
 * - identité
 * - statut du compte
 * - rôles
 * - profil pédagogique
 * - pays
 * - langue d'enseignement
 * - niveau demandé
 * - niveau recommandé
 * - statut du positionnement
 * - score de positionnement
 * - historique des changements de niveau
 * - structure prête pour :
 *      cours
 *      matières
 *      progression
 *      compétences
 *      évaluations
 *      devoirs
 *      emploi du temps
 *      notifications
 *
 * IMPORTANT :
 * Les données pédagogiques officielles viennent de MySQL.
 * Le navigateur ne doit jamais être considéré comme
 * une source officielle.
 * =========================================================
 */


/* =========================================================
   DATABASE
========================================================= */

require_once __DIR__ . '/../config/database.php';


/* =========================================================
   HEADERS
========================================================= */

header(
    'Access-Control-Allow-Origin: https://tiananiaina569-oss.github.io'
);

header(
    'Access-Control-Allow-Methods: GET, OPTIONS'
);

header(
    'Access-Control-Allow-Headers: Content-Type, Authorization'
);

header(
    'Content-Type: application/json; charset=utf-8'
);

header(
    'Cache-Control: no-store, no-cache, must-revalidate, max-age=0'
);

header(
    'Pragma: no-cache'
);


/* =========================================================
   CORS PREFLIGHT
========================================================= */

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {

    http_response_code(204);

    exit;
}


/* =========================================================
   METHOD
========================================================= */

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {

    http_response_code(405);

    echo json_encode(
        [
            'success' => false,
            'message' => 'Method not allowed.'
        ],
        JSON_UNESCAPED_UNICODE |
        JSON_UNESCAPED_SLASHES
    );

    exit;
}


/* =========================================================
   JSON RESPONSE HELPER
========================================================= */

function dashboardResponse(
    bool $success,
    string $message,
    array $data = [],
    int $statusCode = 200
): never {

    http_response_code($statusCode);

    echo json_encode(
        [
            'success' => $success,
            'message' => $message,
            'data' => $data
        ],
        JSON_UNESCAPED_UNICODE |
        JSON_UNESCAPED_SLASHES
    );

    exit;
}


/* =========================================================
   GET AUTHORIZATION HEADER
========================================================= */

function getAuthorizationHeader(): string
{
    if (
        isset($_SERVER['HTTP_AUTHORIZATION']) &&
        $_SERVER['HTTP_AUTHORIZATION'] !== ''
    ) {

        return trim(
            $_SERVER['HTTP_AUTHORIZATION']
        );
    }


    if (
        isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION']) &&
        $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] !== ''
    ) {

        return trim(
            $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
        );
    }


    if (function_exists('getallheaders')) {

        $headers = getallheaders();

        foreach ($headers as $name => $value) {

            if (
                strtolower($name) ===
                'authorization'
            ) {

                return trim($value);
            }
        }
    }


    return '';
}


/* =========================================================
   EXTRACT BEARER TOKEN
========================================================= */

function getBearerToken(): ?string
{
    $header =
        getAuthorizationHeader();


    if ($header === '') {
        return null;
    }


    if (
        !preg_match(
            '/^Bearer\s+(.+)$/i',
            $header,
            $matches
        )
    ) {

        return null;
    }


    $token =
        trim($matches[1]);


    /*
     * Current login.php creates:
     *
     * bin2hex(random_bytes(32))
     *
     * Therefore the token contains
     * exactly 64 hexadecimal characters.
     */

    if (
        !preg_match(
            '/^[a-f0-9]{64}$/i',
            $token
        )
    ) {

        return null;
    }


    return $token;
}


/* =========================================================
   TOKEN
========================================================= */

$token =
    getBearerToken();


if ($token === null) {

    dashboardResponse(
        false,
        'Authentication required.',
        [],
        401
    );
}


/* =========================================================
   DATABASE
========================================================= */

try {

    $pdo =
        getDatabaseConnection();


    /* =====================================================
       SESSION AUTHENTICATION
    ===================================================== */

    $tokenHash =
        hash(
            'sha256',
            $token
        );


    $sessionStatement =
        $pdo->prepare(
            "
            SELECT
                s.id AS session_id,
                s.user_id,
                s.expires_at,
                s.revoked_at,
                s.created_at AS session_created_at,
                s.last_used_at,

                u.id AS user_id,
                u.first_name,
                u.last_name,
                u.email,
                u.status,
                u.account_type,
                u.preferred_language,
                u.country_code,
                u.email_verified_at,
                u.last_login_at,
                u.created_at AS user_created_at,
                u.updated_at AS user_updated_at

            FROM sessions s

            INNER JOIN users u
                ON u.id = s.user_id

            WHERE s.token_hash = :token_hash

            LIMIT 1
            "
        );


    $sessionStatement->execute(
        [
            'token_hash' =>
                $tokenHash
        ]
    );


    $session =
        $sessionStatement->fetch();


    if (!$session) {

        dashboardResponse(
            false,
            'Invalid session.',
            [],
            401
        );
    }


    /* =====================================================
       SESSION EXPIRATION
    ===================================================== */

    if (
        $session['revoked_at'] !== null
    ) {

        dashboardResponse(
            false,
            'Session revoked.',
            [],
            401
        );
    }


    if (
        strtotime(
            (string) $session['expires_at']
        ) <= time()
    ) {

        dashboardResponse(
            false,
            'Session expired.',
            [],
            401
        );
    }


    /* =====================================================
       ACCOUNT STATUS
    ===================================================== */

    if (
        $session['status'] !== 'active'
    ) {

        dashboardResponse(
            false,
            'Account is not active.',
            [
                'account_status' =>
                    $session['status']
            ],
            403
        );
    }


    $userId =
        (string) $session['user_id'];


    /* =====================================================
       UPDATE SESSION ACTIVITY
    ===================================================== */

    $updateSession =
        $pdo->prepare(
            "
            UPDATE sessions

            SET last_used_at = CURRENT_TIMESTAMP

            WHERE id = :session_id

            LIMIT 1
            "
        );


    $updateSession->execute(
        [
            'session_id' =>
                $session['session_id']
        ]
    );


    /* =====================================================
       USER ROLES
    ===================================================== */

    $roleStatement =
        $pdo->prepare(
            "
            SELECT
                r.id,
                r.name,
                r.slug,
                r.description,
                ur.assigned_at

            FROM user_roles ur

            INNER JOIN roles r
                ON r.id = ur.role_id

            WHERE ur.user_id = :user_id

            ORDER BY r.name ASC
            "
        );


    $roleStatement->execute(
        [
            'user_id' =>
                $userId
        ]
    );


    $roles =
        $roleStatement->fetchAll();


    /* =====================================================
       MAIN STUDENT PROFILE
    ===================================================== */

    /*
     * We deliberately use SELECT *
     * here because the education schema
     * can evolve without breaking this endpoint.
     *
     * The API then reads the fields that exist.
     */

    $profileStatement =
        $pdo->prepare(
            "
            SELECT *

            FROM student_profiles

            WHERE user_id = :user_id

            ORDER BY created_at ASC

            LIMIT 1
            "
        );


    $profileStatement->execute(
        [
            'user_id' =>
                $userId
        ]
    );


    $profile =
        $profileStatement->fetch();


    if (!$profile) {

        /*
         * The account can exist before
         * the educational profile is completed.
         */

        $profile =
            null;
    }


    /* =====================================================
       PROFILE RELATED IDS
    ===================================================== */

    $studentProfileId =
        null;

    $requestedLevelId =
        null;

    $recommendedLevelId =
        null;

    $currentLevelId =
        null;

    $validatedLevelId =
        null;

    $countryCode =
        null;

    $instructionLanguage =
        null;

    $educationFieldId =
        null;


    if ($profile) {

        $studentProfileId =
            $profile['id']
            ?? null;


        $requestedLevelId =
            $profile['requested_level_id']
            ?? null;


        $recommendedLevelId =
            $profile['recommended_level_id']
            ?? null;


        $currentLevelId =
            $profile['current_level_id']
            ?? null;


        $validatedLevelId =
            $profile['validated_level_id']
            ?? null;


        $countryCode =
            $profile['country_code']
            ?? $session['country_code']
            ?? null;


        $instructionLanguage =
            $profile['instruction_language']
            ?? $session['preferred_language']
            ?? 'fr';


        $educationFieldId =
            $profile['education_field_id']
            ?? null;
    }


    /*
     * If the current schema does not yet have
     * current_level_id / validated_level_id,
     * the recommended level remains the available
     * pedagogical reference.
     */

    $effectiveLevelId =
        $validatedLevelId
        ?: $currentLevelId
        ?: $recommendedLevelId;


    /* =====================================================
       EDUCATION LEVEL HELPER
    ===================================================== */

    function getEducationLevel(
        PDO $pdo,
        $levelId
    ): ?array {

        if (
            $levelId === null ||
            $levelId === ''
        ) {

            return null;
        }


        $statement =
            $pdo->prepare(
                "
                SELECT *

                FROM education_levels

                WHERE id = :id

                LIMIT 1
                "
            );


        $statement->execute(
            [
                'id' =>
                    $levelId
            ]
        );


        $level =
            $statement->fetch();


        return $level ?: null;
    }


    $requestedLevel =
        getEducationLevel(
            $pdo,
            $requestedLevelId
        );


    $recommendedLevel =
        getEducationLevel(
            $pdo,
            $recommendedLevelId
        );


    $currentLevel =
        getEducationLevel(
            $pdo,
            $effectiveLevelId
        );


    /* =====================================================
       COUNTRY
    ===================================================== */

    $country =
        null;


    if (
        $countryCode !== null &&
        $countryCode !== ''
    ) {

        $countryStatement =
            $pdo->prepare(
                "
                SELECT *

                FROM countries

                WHERE code = :code

                LIMIT 1
                "
            );


        $countryStatement->execute(
            [
                'code' =>
                    $countryCode
            ]
        );


        $country =
            $countryStatement->fetch()
            ?: null;
    }


    /* =====================================================
       EDUCATION LANGUAGE
    ===================================================== */

    $language =
        null;


    if (
        $instructionLanguage !== null &&
        $instructionLanguage !== ''
    ) {

        $languageStatement =
            $pdo->prepare(
                "
                SELECT *

                FROM education_languages

                WHERE code = :code

                LIMIT 1
                "
            );


        $languageStatement->execute(
            [
                'code' =>
                    $instructionLanguage
            ]
        );


        $language =
            $languageStatement->fetch()
            ?: null;
    }


    /* =====================================================
       EDUCATION FIELD
    ===================================================== */

    $educationField =
        null;


    if (
        $educationFieldId !== null &&
        $educationFieldId !== ''
    ) {

        $fieldStatement =
            $pdo->prepare(
                "
                SELECT *

                FROM education_fields

                WHERE id = :id

                LIMIT 1
                "
            );


        $fieldStatement->execute(
            [
                'id' =>
                    $educationFieldId
            ]
        );


        $educationField =
            $fieldStatement->fetch()
            ?: null;
    }


    /* =====================================================
       LEVEL HISTORY
    ===================================================== */

    $levelHistory =
        [];


    if ($studentProfileId !== null) {

        $historyStatement =
            $pdo->prepare(
                "
                SELECT
                    h.*,

                    previous_level.code
                        AS previous_level_code,

                    previous_level.name
                        AS previous_level_name,

                    new_level.code
                        AS new_level_code,

                    new_level.name
                        AS new_level_name

                FROM student_level_history h

                LEFT JOIN education_levels previous_level
                    ON previous_level.id =
                       h.previous_level_id

                LEFT JOIN education_levels new_level
                    ON new_level.id =
                       h.new_level_id

                WHERE h.student_profile_id =
                      :student_profile_id

                ORDER BY h.created_at DESC
                "
            );


        $historyStatement->execute(
            [
                'student_profile_id' =>
                    $studentProfileId
            ]
        );


        $levelHistory =
            $historyStatement->fetchAll();
    }


    /* =====================================================
       STUDENT DATA CLEANING
    ===================================================== */

    $userData = [

        'id' =>
            $session['user_id'],

        'first_name' =>
            $session['first_name'],

        'last_name' =>
            $session['last_name'],

        'full_name' =>
            trim(
                $session['first_name'] .
                ' ' .
                $session['last_name']
            ),

        'email' =>
            $session['email'],

        'status' =>
            $session['status'],

        'account_type' =>
            $session['account_type'],

        'preferred_language' =>
            $session['preferred_language'],

        'country_code' =>
            $session['country_code'],

        'email_verified_at' =>
            $session['email_verified_at'],

        'last_login_at' =>
            $session['last_login_at'],

        'created_at' =>
            $session['user_created_at'],

        'updated_at' =>
            $session['user_updated_at']
    ];


    /* =====================================================
       PEDAGOGICAL PROFILE
    ===================================================== */

    $profileData =
        null;


    if ($profile) {

        $profileData = [

            'id' =>
                $studentProfileId,

            'country_code' =>
                $countryCode,

            'instruction_language' =>
                $instructionLanguage,

            'education_stage' =>
                $profile['education_stage']
                ?? null,

            'requested_level' =>
                $requestedLevel,

            'recommended_level' =>
                $recommendedLevel,

            'current_level' =>
                $currentLevel,

            'education_field' =>
                $educationField,

            'learning_goal' =>
                $profile['learning_goal']
                ?? null,

            'placement_score' =>
                $profile['placement_score']
                ?? null,

            'placement_status' =>
                $profile['placement_status']
                ?? null,

            'placement_completed_at' =>
                $profile['placement_completed_at']
                ?? null,

            'country' =>
                $country,

            'language' =>
                $language,

            'created_at' =>
                $profile['created_at']
                ?? null,

            'updated_at' =>
                $profile['updated_at']
                ?? null
        ];
    }


    /* =====================================================
       DASHBOARD STRUCTURE
    ===================================================== */

    /*
     * Ces blocs sont volontairement structurés.
     *
     * Ils seront alimentés par les prochaines tables
     * pédagogiques au fur et à mesure de leur création.
     *
     * Nous ne mettons PAS de faux cours,
     * faux résultats ou faux pourcentages.
     */

    $dashboard = [

        'user' =>
            $userData,

        'roles' =>
            $roles,

        'profile' =>
            $profileData,

        'level_history' =>
            $levelHistory,


        'next_lesson' =>
            null,


        'progress' =>
            [
                'global' => null,

                'courses_completed' => 0,

                'lessons_completed' => 0,

                'exercises_completed' => 0,

                'evaluations_completed' => 0,

                'competencies_validated' => 0
            ],


        'subjects' =>
            [],


        'competencies' =>
            [],


        'courses' =>
            [],


        'lessons' =>
            [],


        'exercises' =>
            [],


        'evaluations' =>
            [],


   
