<?php

declare(strict_types=1);

/**
 * ============================================================
 * DeepRDMMakademy
 * Current User / Session API
 * ============================================================
 *
 * Fichier situé à la racine du projet :
 *
 * DeepRDMMakademy/
 * └── me.php
 *
 * La configuration de la base se trouve ici :
 *
 * DeepRDMMakademy/
 * └── api/
 *     └── config/
 *         └── database.php
 *
 * Fonctionnalités :
 * - Vérification du token Bearer
 * - Vérification de la session
 * - Vérification de l'expiration
 * - Vérification du statut du compte
 * - Révocation automatique si nécessaire
 * - Récupération des rôles
 * - Mise à jour de last_used_at
 * - Journalisation de l'activité
 * ============================================================
 */


/*
|--------------------------------------------------------------------------
| Database configuration
|--------------------------------------------------------------------------
|
| IMPORTANT :
| Ce fichier me.php est à la racine.
|
| Le bon chemin est donc :
|
| /api/config/database.php
|
*/

require_once __DIR__ . '/api/config/database.php';


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

if (
    ($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS'
) {

    http_response_code(204);

    exit;
}


/*
|--------------------------------------------------------------------------
| JSON response helper
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

if (
    ($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET'
) {

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

$authorization = '';


/*
 * Méthode 1 :
 * Apache / PHP fournit directement HTTP_AUTHORIZATION.
 */

if (
    isset($_SERVER['HTTP_AUTHORIZATION'])
) {

    $authorization = trim(
        (string)$_SERVER['HTTP_AUTHORIZATION']
    );
}


/*
 * Méthode 2 :
 * Certains serveurs utilisent REDIRECT_HTTP_AUTHORIZATION.
 */

if (
    $authorization === '' &&
    isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])
) {

    $authorization = trim(
        (string)$_SERVER['REDIRECT_HTTP_AUTHORIZATION']
    );
}


/*
 * Méthode 3 :
 * Certains environnements peuvent exposer
 * l'en-tête Authorization via getallheaders().
 */

if (
    $authorization === '' &&
    function_exists('getallheaders')
) {

    $headers = getallheaders();

    if (
        is_array($headers)
    ) {

        foreach ($headers as $name => $value) {

            if (
                strtolower((string)$name) === 'authorization'
            ) {

                $authorization = trim(
                    (string)$value
                );

                break;
            }
        }
    }
}


/*
|--------------------------------------------------------------------------
| Authorization required
|--------------------------------------------------------------------------
*/

if (
    $authorization === ''
) {

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
        $authorization,
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


$rawToken = trim(
    (string)$matches[1]
);


/*
|--------------------------------------------------------------------------
| Token format
|--------------------------------------------------------------------------
|
| Le login génère 32 octets aléatoires convertis en hexadécimal.
| Cela produit exactement 64 caractères hexadécimaux.
|
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


/*
|--------------------------------------------------------------------------
| Hash token
|--------------------------------------------------------------------------
|
| Le token brut n'est jamais recherché directement en base.
| La base contient uniquement son SHA-256.
|
*/

$tokenHash = hash(
    'sha256',
    $rawToken
);


/*
|--------------------------------------------------------------------------
| Client IP
|--------------------------------------------------------------------------
*/

$ipAddress = $_SERVER['REMOTE_ADDR'] ?? null;


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
    | Find session + user
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

    if (
        !$session
    ) {

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

    if (
        $session['revoked_at'] !== null
    ) {

        sendJson(
            false,
            'Session invalide ou expirée.',
            [],
            401
        );
    }


    /*
    |--------------------------------------------------------------------------
    | Session expiration
    |--------------------------------------------------------------------------
    */

    try {

        $now = new DateTimeImmutable();

        $expiresAt = new DateTimeImmutable(
            (string)$session['expires_at']
        );

    } catch (
        Throwable $exception
    ) {

        error_log(
            'DeepRDMMakademy invalid session expiration: ' .
            $exception->getMessage()
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
    | Expired
    |--------------------------------------------------------------------------
    */

    if (
        $expiresAt <= $now
    ) {

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
    | Un token encore valide ne doit pas permettre l'accès
    | si le compte a été suspendu, bloqué ou désactivé.
    |
    */

    if (
        $session['status'] !== 'active'
    ) {

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
    | Update session activity
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
    | Retrieve user roles
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


    foreach (
        $roles as $role
    ) {

        $formattedRoles[] = [
            'id' => (int)$role['id'],

            'name' => $role['name'],

            'slug' => $role['slug'],

            'description' => $role['description'],
        ];
    }


    /*
    |--------------------------------------------------------------------------
    | Audit log
    |--------------------------------------------------------------------------
    |
    | IMPORTANT :
    | Le token n'est jamais enregistré dans les logs.
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
            ':user_id' =>
                $session['user_id'],

            ':action' =>
                'SESSION_VERIFIED',

            ':entity_type' =>
                'session',

            ':entity_id' =>
                $session['session_id'],

            ':ip_address' =>
                $ipAddress,
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

            /*
            |--------------------------------------------------------------------------
            | Authentication state
            |--------------------------------------------------------------------------
            */

            'authenticated' => true,


            /*
            |--------------------------------------------------------------------------
            | User
            |--------------------------------------------------------------------------
            */

            'user' => [

                'id' =>
                    $session['user_id'],

                'first_name' =>
                    $session['first_name'],

                'last_name' =>
                    $session['last_name'],

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
                    $session['created_at'],
            ],


            /*
            |--------------------------------------------------------------------------
            | Roles
            |--------------------------------------------------------------------------
            */

            'roles' =>
                $formattedRoles,


            /*
            |--------------------------------------------------------------------------
            | Session
            |--------------------------------------------------------------------------
            */

            'session' => [

                'id' =>
                    $session['session_id'],

                'expires_at' =>
                    $session['expires_at'],
            ],
        ],
        200
    );


} catch (
    Throwable $exception
) {

    /*
    |--------------------------------------------------------------------------
    | Error logging
    |--------------------------------------------------------------------------
    */

    error_log(
        'DeepRDMMakademy session verification error: ' .
        $exception->getMessage()
    );


    /*
    |--------------------------------------------------------------------------
    | Safe error response
    |--------------------------------------------------------------------------
    */

    sendJson(
        false,
        'Une erreur est survenue lors de la vérification de la session.',
        [],
        500
    );
}
