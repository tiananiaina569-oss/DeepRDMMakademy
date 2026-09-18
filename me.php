<?php

declare(strict_types=1);

/**
 * ============================================================
 * DeepRDMMakademy
 * Current User / Session API
 * ============================================================
 *
 * Vérifie le token de session et retourne l'utilisateur connecté.
 * ============================================================
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
    header(
        'Access-Control-Allow-Origin: ' . $allowedOrigin
    );

    header('Vary: Origin');
}

header(
    'Access-Control-Allow-Methods: GET, OPTIONS'
);

header(
    'Access-Control-Allow-Headers: Content-Type, Authorization'
);

header(
    'Content-Type: application/json; charset=utf-8'
);


/*
|--------------------------------------------------------------------------
| OPTIONS
|--------------------------------------------------------------------------
*/

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {

    http_response_code(204);

    exit;
}


/*
|--------------------------------------------------------------------------
| JSON response
|--------------------------------------------------------------------------
*/

function sendJson(
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
            'data'    => $data,
        ],
        JSON_UNESCAPED_UNICODE |
        JSON_UNESCAPED_SLASHES
    );

    exit;
}


/*
|--------------------------------------------------------------------------
| Request method
|--------------------------------------------------------------------------
*/

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {

    sendJson(
        false,
        'Méthode non autorisée.',
        [],
        405
    );
}


/*
|--------------------------------------------------------------------------
| Authorization header
|--------------------------------------------------------------------------
*/

$authorization = $_SERVER['HTTP_AUTHORIZATION'] ?? '';

if ($authorization === '') {

    sendJson(
        false,
        'Authentification requise.',
        [],
        401
    );
}


/*
|--------------------------------------------------------------------------
| Extract Bearer token
|--------------------------------------------------------------------------
*/

if (
    !preg_match(
        '/^Bearer\s+(.+)$/i',
        trim($authorization),
        $matches
    )
) {

    sendJson(
        false,
        'Authentification invalide.',
        [],
        401
    );
}


$rawToken = trim($matches[1]);


/*
|--------------------------------------------------------------------------
| Token validation
|--------------------------------------------------------------------------
*/

if (
    $rawToken === '' ||
    !preg_match(
        '/^[a-f0-9]{64}$/i',
        $rawToken
    )
) {

    sendJson(
        false,
        'Authentification invalide.',
        [],
        401
    );
}


$tokenHash = hash(
    'sha256',
    $rawToken
);


/*
|--------------------------------------------------------------------------
| Database
|--------------------------------------------------------------------------
*/

$pdo = null;

try {

    $pdo = getDatabaseConnection();


    /*
    |--------------------------------------------------------------------------
    | Find valid session + user
    |--------------------------------------------------------------------------
    */

    $query = $pdo->prepare(
        'SELECT
            s.id AS session_id,
            s.user_id,
            s.expires_at,
            s.revoked_at,
            u.first_name,
            u.last_name,
            u.email,
            u.status,
            u.account_type,
            u.preferred_language,
            u.country_code,
            u.email_verified_at,
            u.last_login_at,
            u.created_at
         FROM sessions s
         INNER JOIN users u
            ON u.id = s.user_id
         WHERE s.token_hash = :token_hash
         LIMIT 1'
    );


    $query->execute(
        [
            ':token_hash' => $tokenHash,
        ]
    );


    $session = $query->fetch();


    /*
    |--------------------------------------------------------------------------
    | Session not found
    |--------------------------------------------------------------------------
    */

    if (!$session) {

        sendJson(
            false,
            'Session invalide ou expirée.',
            [],
            401
        );
    }


    /*
    |--------------------------------------------------------------------------
    | Revoked session
    |--------------------------------------------------------------------------
    */

    if ($session['revoked_at'] !== null) {

        sendJson(
            false,
            'Session invalide ou expirée.',
            [],
            401
        );
    }


    /*
    |--------------------------------------------------------------------------
    | Expired session
    |--------------------------------------------------------------------------
    */

    $now = new DateTimeImmutable();

    $expiresAt = new DateTimeImmutable(
        $session['expires_at']
    );


    if ($expiresAt <= $now) {

        /*
         * Marquer la session comme expirée.
         */

        $expireSession = $pdo->prepare(
            'UPDATE sessions
             SET revoked_at = NOW()
             WHERE id = :session_id
             AND revoked_at IS NULL'
        );


        $expireSession->execute(
            [
                ':session_id' => $session['session_id'],
            ]
        );


        sendJson(
            false,
            'Session invalide ou expirée.',
            [],
            401
        );
    }


    /*
    |--------------------------------------------------------------------------
    | Account status
    |--------------------------------------------------------------------------
    |
    | Même avec un token valide, l'utilisateur ne doit plus
    | accéder au système si son compte a été désactivé.
    |
    */

    if ($session['status'] !== 'active') {

        /*
         * Révoquer immédiatement la session.
         */

        $revokeSession = $pdo->prepare(
            'UPDATE sessions
             SET revoked_at = NOW()
             WHERE id = :session_id
             AND revoked_at IS NULL'
        );


        $revokeSession->execute(
            [
                ':session_id' => $session['session_id'],
            ]
        );


        sendJson(
            false,
            'Votre compte n’est plus actif.',
            [],
            403
        );
    }


    /*
    |--------------------------------------------------------------------------
    | Update last used
    |--------------------------------------------------------------------------
    */

    $updateSession = $pdo->prepare(
        'UPDATE sessions
         SET last_used_at = NOW()
         WHERE id = :session_id'
    );


    $updateSession->execute(
        [
            ':session_id' => $session['session_id'],
        ]
    );


    /*
    |--------------------------------------------------------------------------
    | Retrieve roles
    |--------------------------------------------------------------------------
    */

    $roleQuery = $pdo->prepare(
        'SELECT
            r.id,
            r.name,
            r.slug,
            r.description
         FROM user_roles ur
         INNER JOIN roles r
            ON r.id = ur.role_id
         WHERE ur.user_id = :user_id
         ORDER BY r.id ASC'
    );


    $roleQuery->execute(
        [
            ':user_id' => $session['user_id'],
        ]
    );


    $roles = $roleQuery->fetchAll();


    /*
    |--------------------------------------------------------------------------
    | Format roles
    |--------------------------------------------------------------------------
    */

    $formattedRoles = [];

    foreach ($roles as $role) {

        $formattedRoles[] = [
            'id'          => (int)$role['id'],
            'name'        => $role['name'],
            'slug'        => $role['slug'],
            'description' => $role['description'],
        ];
    }


    /*
    |--------------------------------------------------------------------------
    | Audit log
    |--------------------------------------------------------------------------
    |
    | On ne journalise pas le token.
    |
    */

    $audit = $pdo->prepare(
        'INSERT INTO audit_logs
        (
            user_id,
            action,
            entity_type,
            entity_id,
            ip_address
        )
        VALUES
        (
            :user_id,
            :action,
            :entity_type,
            :entity_id,
            :ip_address
        )'
    );


    $audit->execute(
        [
            ':user_id'     => $session['user_id'],
            ':action'      => 'SESSION_VERIFIED',
            ':entity_type' => 'session',
            ':entity_id'   => $session['session_id'],
            ':ip_address'  => $_SERVER['REMOTE_ADDR'] ?? null,
        ]
    );


    /*
    |--------------------------------------------------------------------------
    | Success
    |--------------------------------------------------------------------------
    */

    sendJson(
        true,
        'Session valide.',
        [
            'authenticated' => true,

            'user' => [
                'id'                 => $session['user_id'],
                'first_name'         => $session['first_name'],
                'last_name'          => $session['last_name'],
                'email'              => $session['email'],
                'status'             => $session['status'],
                'account_type'       => $session['account_type'],
                'preferred_language' => $session['preferred_language'],
                'country_code'       => $session['country_code'],
                'email_verified_at'  => $session['email_verified_at'],
                'last_login_at'      => $session['last_login_at'],
                'created_at'         => $session['created_at'],
            ],

            'roles' => $formattedRoles,

            'session' => [
                'id'         => $session['session_id'],
                'expires_at' => $session['expires_at'],
            ],
        ],
        200
    );


} catch (Throwable $exception) {

    error_log(
        'DeepRDMMakademy session verification error: ' .
        $exception->getMessage()
    );


    sendJson(
        false,
        'Une erreur est survenue lors de la vérification de la session.',
        [],
        500
    );
}
