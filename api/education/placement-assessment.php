<?php

declare(strict_types=1);

/**
 * DeepRDMMakademy
 * Placement Assessment API
 *
 * Endpoint:
 * POST /api/education/placement-assessment.php
 *
 * Rôle :
 * - authentifier l'étudiant
 * - recevoir les réponses de placement
 * - calculer le score côté serveur
 * - déterminer une recommandation de niveau
 * - enregistrer le résultat
 * - conserver un historique
 */

require_once __DIR__ . '/../config/database.php';

/*
|--------------------------------------------------------------------------
| CORS
|--------------------------------------------------------------------------
*/

$allowedOrigin = 'https://tiananiaina569-oss.github.io';

if (
    isset($_SERVER['HTTP_ORIGIN']) &&
    $_SERVER['HTTP_ORIGIN'] === $allowedOrigin
) {
    header('Access-Control-Allow-Origin: ' . $allowedOrigin);
    header('Vary: Origin');
}

header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

/*
|--------------------------------------------------------------------------
| JSON response
|--------------------------------------------------------------------------
*/

function jsonResponse(
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
            'data' => $data,
        ],
        JSON_UNESCAPED_UNICODE |
        JSON_UNESCAPED_SLASHES
    );

    exit;
}

/*
|--------------------------------------------------------------------------
| Authorization
|--------------------------------------------------------------------------
*/

function getAuthorizationToken(): ?string
{
    $header = '';

    if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $header = trim($_SERVER['HTTP_AUTHORIZATION']);
    } elseif (isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
        $header = trim($_SERVER['REDIRECT_HTTP_AUTHORIZATION']);
    } elseif (function_exists('getallheaders')) {

        $headers = getallheaders();

        foreach ($headers as $name => $value) {

            if (strtolower($name) === 'authorization') {
                $header = trim($value);
                break;
            }
        }
    }

    if ($header === '') {
        return null;
    }

    if (
        !preg_match(
            '/^Bearer\s+([a-fA-F0-9]{64})$/',
            $header,
            $matches
        )
    ) {
        return null;
    }

    return $matches[1];
}

/*
|--------------------------------------------------------------------------
| Request method
|--------------------------------------------------------------------------
*/

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(
        false,
        'Method not allowed.',
        [],
        405
    );
}

/*
|--------------------------------------------------------------------------
| Authenticate session
|--------------------------------------------------------------------------
*/

$rawToken = getAuthorizationToken();

if ($rawToken === null) {
    jsonResponse(
        false,
        'Authentication required.',
        [],
        401
    );
}

$tokenHash = hash(
    'sha256',
    $rawToken
);

try {

    $pdo = getDatabaseConnection();

    /*
    |--------------------------------------------------------------------------
    | Find session
    |--------------------------------------------------------------------------
    */

    $sessionStatement = $pdo->prepare(
        '
        SELECT
            s.id AS session_id,
            s.user_id,
            s.expires_at,
            s.revoked_at,
            u.status,
            u.account_type
        FROM sessions s
        INNER JOIN users u
            ON u.id = s.user_id
        WHERE s.token_hash = :token_hash
        LIMIT 1
        '
    );

    $sessionStatement->execute(
        [
            ':token_hash' => $tokenHash,
        ]
    );

    $session = $sessionStatement->fetch();

    if (!$session) {
        jsonResponse(
            false,
            'Invalid session.',
            [],
            401
        );
    }

    /*
    |--------------------------------------------------------------------------
    | Validate session
    |--------------------------------------------------------------------------
    */

    if ($session['revoked_at'] !== null) {
        jsonResponse(
            false,
            'Session revoked.',
            [],
            401
        );
    }

    if (
        strtotime((string) $session['expires_at']) <= time()
    ) {
        jsonResponse(
            false,
            'Session expired.',
            [],
            401
        );
    }

    if ($session['status'] !== 'active') {
        jsonResponse(
            false,
            'Account is not active.',
            [],
            403
        );
    }

    $userId = (string) $session['user_id'];

    /*
    |--------------------------------------------------------------------------
    | Read request
    |--------------------------------------------------------------------------
    */

    $rawBody = file_get_contents('php://input');

    if (
        $rawBody === false ||
        trim($rawBody) === ''
    ) {
        jsonResponse(
            false,
            'Request body is required.',
            [],
            400
        );
    }

    $payload = json_decode(
        $rawBody,
        true
    );

    if (
        !is_array($payload) ||
        json_last_error() !== JSON_ERROR_NONE
    ) {
        jsonResponse(
            false,
            'Invalid JSON payload.',
            [],
            400
        );
    }

    /*
    |--------------------------------------------------------------------------
    | Get student profile
    |--------------------------------------------------------------------------
    */

    $profileStatement = $pdo->prepare(
        '
        SELECT
            sp.id,
            sp.requested_level_id,
            sp.recommended_level_id,
            sp.validated_level_id,
            sp.current_level_id,
            sp.placement_status,
            el.code AS requested_level_code,
            el.name AS requested_level_name
        FROM student_profiles sp
        LEFT JOIN education_levels el
            ON el.id = sp.requested_level_id
        WHERE sp.user_id = :user_id
        LIMIT 1
        '
    );

    $profileStatement->execute(
        [
            ':user_id' => $userId,
        ]
    );

    $profile = $profileStatement->fetch();

    if (!$profile) {
        jsonResponse(
            false,
            'Student profile not found.',
            [],
            404
        );
    }

    /*
    |--------------------------------------------------------------------------
    | Read answers
    |--------------------------------------------------------------------------
    |
    | Expected format:
    |
    | {
    |   "answers": {
    |      "logic": 2,
    |      "math": 2,
    |      "science": 0
    |   }
    | }
    |
    */

    $answers = $payload['answers'] ?? null;

    if (!is_array($answers)) {
        jsonResponse(
            false,
            'Assessment answers are required.',
            [],
            422
        );
    }

    if (count($answers) === 0) {
        jsonResponse(
            false,
            'Assessment cannot be empty.',
            [],
            422
        );
    }

    /*
    |--------------------------------------------------------------------------
    | Server-side question bank
    |--------------------------------------------------------------------------
    |
    | Important:
    | The browser must not be trusted to send the score.
    |
    | The server calculates the score from the official
    | answer key defined here.
    |
    */

    $questionBank = [

        'logic' => [
            'correct' => 2,
            'points' => 2,
            'competency' => 'reasoning'
        ],

        'math' => [
            'correct' => 2,
            'points' => 2,
            'competency' => 'mathematics'
        ],

        'science' => [
            'correct' => 1,
            'points' => 2,
            'competency' => 'science'
        ],

        'language' => [
            'correct' => 0,
            'points' => 2,
            'competency' => 'language'
        ],

        'physics' => [
            'correct' => 2,
            'points' => 2,
            'competency' => 'physics'
        ],

        'digital' => [
            'correct' => 0,
            'points' => 2,
            'competency' => 'digital'
        ],

        'biology' => [
            'correct' => 0,
            'points' => 2,
            'competency' => 'biology'
        ],

        'analysis' => [
            'correct' => 2,
            'points' => 2,
            'competency' => 'analysis'
        ],

        'critical' => [
            'correct' => 1,
            'points' => 2,
            'competency' => 'critical_thinking'
        ],

        'problem' => [
            'correct' => 1,
            'points' => 2,
            'competency' => 'problem_solving'
        ],
    ];

    /*
    |--------------------------------------------------------------------------
    | Calculate server-side result
    |--------------------------------------------------------------------------
    */

    $score = 0;
    $maximumScore = 0;

    $competencies = [];

    $answeredQuestions = 0;

    foreach ($questionBank as $questionId => $question) {

        $maximumScore += (int) $question['points'];

        if (!array_key_exists(
            $questionId,
            $answers
        )) {
            continue;
        }

        $selectedAnswer = $answers[$questionId];

        if (
            !is_numeric($selectedAnswer)
        ) {
            continue;
        }

        $selectedAnswer = (int) $selectedAnswer;

        $answeredQuestions++;

        $competency =
            (string) $question['competency'];

        if (!isset($competencies[$competency])) {
            $competencies[$competency] = [
                'score' => 0,
                'maximum' => 0
            ];
        }

        $competencies[$competency]['maximum'] +=
            (int) $question['points'];

        if (
            $selectedAnswer ===
            (int) $question['correct']
        ) {

            $score +=
                (int) $question['points'];

            $competencies[$competency]['score'] +=
                (int) $question['points'];
        }
    }

    /*
    |--------------------------------------------------------------------------
    | Require complete assessment
    |--------------------------------------------------------------------------
    */

    if (
        $answeredQuestions <
        count($questionBank)
    ) {
        jsonResponse(
            false,
            'The assessment must be completed before submission.',
            [
                'answered' => $answeredQuestions,
                'required' => count($questionBank),
            ],
            422
        );
    }

    /*
    |--------------------------------------------------------------------------
    | Calculate percentage
    |--------------------------------------------------------------------------
    */

    $percentage = 0;

    if ($maximumScore > 0) {
        $percentage = round(
            ($score / $maximumScore) * 100,
            2
        );
    }

    /*
    |--------------------------------------------------------------------------
    | Determine recommendation
    |--------------------------------------------------------------------------
    |
    | This is intentionally conservative.
    |
    | A real curriculum-specific placement engine can later
    | use education_levels, competencies, prerequisites,
    | curriculum systems and subject mastery.
    |
    */

    $recommendedLevelId = null;
    $recommendedLevelCode = null;
    $recommendedLevelName = null;

    /*
    |--------------------------------------------------------------------------
    | Build ordered levels
    |--------------------------------------------------------------------------
    */

    $levelsStatement = $pdo->query(
        '
        SELECT
            id,
            code,
            name,
            stage,
            sort_order
        FROM education_levels
        WHERE is_active = 1
        ORDER BY
            sort_order ASC,
            id ASC
        '
    );

    $levels = $levelsStatement->fetchAll();

    /*
    |--------------------------------------------------------------------------
    | Determine approximate level position
    |--------------------------------------------------------------------------
    */

    if (count($levels) > 0) {

        $levelCount = count($levels);

        if ($percentage >= 85) {

            $targetIndex =
                $levelCount - 1;

        } elseif ($percentage >= 65) {

            $targetIndex =
                max(
                    0,
                    (int) floor(
                        ($levelCount - 1) * 0.70
                    )
                );

        } elseif ($percentage >= 45) {

            $targetIndex =
                max(
                    0,
                    (int) floor(
                        ($levelCount - 1) * 0.45
                    )
                );

        } else {

            $targetIndex =
                0;
        }

        if (isset($levels[$targetIndex])) {

            $recommendedLevelId =
                (int) $levels[$targetIndex]['id'];

            $recommendedLevelCode =
                $levels[$targetIndex]['code'];

            $recommendedLevelName =
                $levels[$targetIndex]['name'];
        }
    }

    /*
    |--------------------------------------------------------------------------
    | Fallback
    |--------------------------------------------------------------------------
    |
    | If no level can be determined, the placement remains
    | pending instead of inventing a level.
    |
    */

    $placementStatus =
        $recommendedLevelId !== null
            ? 'recommended'
            : 'pending';

    /*
    |--------------------------------------------------------------------------
    | Transaction
    |--------------------------------------------------------------------------
    */

    $pdo->beginTransaction();

    try {

        /*
        |--------------------------------------------------------------------------
        | Update student profile
        |--------------------------------------------------------------------------
        */

        $updateProfile = $pdo->prepare(
            '
            UPDATE student_profiles
            SET
                recommended_level_id = :recommended_level_id,
                placement_score = :placement_score,
                placement_status = :placement_status,
                placement_completed_at = CURRENT_TIMESTAMP,
                updated_at = CURRENT_TIMESTAMP
            WHERE user_id = :user_id
            '
        );

        $updateProfile->execute(
            [
                ':recommended_level_id' =>
                    $recommendedLevelId,

                ':placement_score' =>
                    $percentage,

                ':placement_status' =>
                    $placementStatus,

                ':user_id' =>
                    $userId,
            ]
        );

        /*
        |--------------------------------------------------------------------------
        | Create placement history
        |--------------------------------------------------------------------------
        */

        $historyId = sprintf(
            '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
            random_int(0, 0xffff),
            random_int(0, 0xffff),
            random_int(0, 0xffff),
            random_int(0, 0x0fff) | 0x4000,
            random_int(0, 0x3fff) | 0x8000,
            random_int(0, 0xffff),
            random_int(0, 0xffff),
            random_int(0, 0xffff)
        );

        /*
        |--------------------------------------------------------------------------
        | Store history
        |--------------------------------------------------------------------------
        |
        | The history table is designed to preserve changes in
        | educational placement.
        |
        */

        $historyStatement = $pdo->prepare(
            '
            INSERT INTO student_level_history (
                id,
                student_profile_id,
                previous_level_id,
                new_level_id,
                change_type,
                reason,
                changed_by,
                created_at
            )
            VALUES (
                :id,
                :student_profile_id,
                :previous_level_id,
                :new_level_id,
                :change_type,
                :reason,
                :changed_by,
                CURRENT_TIMESTAMP
            )
            '
        );

        $historyStatement->execute(
            [
                ':id' =>
                    $historyId,

                ':student_profile_id' =>
                    $profile['id'],

                ':previous_level_id' =>
                    $profile['current_level_id'],

                ':new_level_id' =>
                    $recommendedLevelId,

                ':change_type' =>
                    'placement',

                ':reason' =>
                    'Automatic placement assessment.',

                ':changed_by' =>
                    $userId,
            ]
        );

        /*
        |--------------------------------------------------------------------------
        | Audit log
        |--------------------------------------------------------------------------
        */

        $auditDetails = json_encode(
            [
                'score' => $score,
                'maximum_score' => $maximumScore,
                'percentage' => $percentage,
                'answered_questions' => $answeredQuestions,
                'recommended_level_id' =>
                    $recommendedLevelId,
                'recommended_level_code' =>
                    $recommendedLevelCode,
                'competencies' =>
                    $competencies,
            ],
            JSON_UNESCAPED_UNICODE |
            JSON_UNESCAPED_SLASHES
        );

        $auditStatement = $pdo->prepare(
            '
            INSERT INTO audit_logs (
                user_id,
                action,
                entity_type,
                entity_id,
                ip_address,
                details,
                created_at
            )
            VALUES (
                :user_id,
                :action,
                :entity_type,
                :entity_id,
                :ip_address,
                :details,
                CURRENT_TIMESTAMP
            )
            '
        );

        $auditStatement->execute(
            [
                ':user_id' =>
                    $userId,

                ':action' =>
                    'PLACEMENT_ASSESSMENT_COMPLETED',

                ':entity_type' =>
                    'student_profile',

                ':entity_id' =>
                    $profile['id'],

                ':ip_address' =>
                    $_SERVER['REMOTE_ADDR'] ?? null,

                ':details' =>
                    $auditDetails,
            ]
        );

        /*
        |--------------------------------------------------------------------------
        | Update session activity
        |--------------------------------------------------------------------------
        */

        $sessionUpdate = $pdo->prepare(
            '
            UPDATE sessions
            SET last_used_at = CURRENT_TIMES
