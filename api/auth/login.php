<?php

declare(strict_types=1);

/**
 * ============================================================
 * DeepRDMMakademy
 * Login API
 * ============================================================
 *
 * PHP 8.x + MySQL / MariaDB
 *
 * Fonctionnalités :
 * - Connexion sécurisée
 * - Vérification du mot de passe
 * - Limitation des tentatives
 * - Création de session serveur
 * - Token Bearer sécurisé
 * - Journalisation des connexions
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
    'Access-Control-Allow-Methods: POST, OPTIONS'
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

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {

    sendJson(
        false,
        'Méthode non autorisée.',
        [],
        405
    );
}


/*
|--------------------------------------------------------------------------
| Read JSON
|--------------------------------------------------------------------------
*/

$rawInput = file_get_contents('php://input');

if (
    $rawInput === false ||
    trim($rawInput) === ''
) {

    sendJson(
        false,
        'Aucune donnée reçue.',
        [],
        400
    );
}


$input = json_decode(
    $rawInput,
    true
);

if (
    !is_array($input) ||
    json_last_error() !== JSON_ERROR_NONE
) {

    sendJson(
        false,
        'Les données reçues sont invalides.',
        [],
        400
    );
}


/*
|--------------------------------------------------------------------------
| Input
|--------------------------------------------------------------------------
*/

$email = strtolower(
    trim(
        (string)($input['email'] ?? '')
    )
);

$password = (string)(
    $input['password'] ?? ''
);


/*
|--------------------------------------------------------------------------
| Validation
|--------------------------------------------------------------------------
*/

if (
    !filter_var(
        $email,
        FILTER_VALIDATE_EMAIL
    )
) {

    sendJson(
        false,
        'Adresse e-mail ou mot de passe incorrect.',
        [],
        401
    );
}

if ($password === '') {

    sendJson(
        false,
        'Adresse e-mail ou mot de passe incorrect.',
        [],
        401
    );
}


/*
|--------------------------------------------------------------------------
| Client information
|--------------------------------------------------------------------------
*/

$ipAddress = $_SERVER['REMOTE_ADDR'] ?? null;

$userAgent = $_SERVER['HTTP_USER_AGENT'] ?? null;


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
    | Protection against repeated login failures
    |--------------------------------------------------------------------------
    |
    | Maximum : 5 échecs dans les 15 dernières minutes
    |
    */

    $attemptWindowMinutes = 15;

    $maxFailedAttempts = 5;


    $attemptQuery = $pdo->prepare(
        'SELECT COUNT(*) AS failed_attempts
         FROM login_attempts
         WHERE success = 0
         AND attempted_at >= DATE_SUB(
             NOW(),
             INTERVAL :minutes MINUTE
         )
         AND (
             email = :email
             OR ip_address = :ip_address
         )'
    );


    /*
     * MySQL/MariaDB peut avoir des restrictions avec
     * les paramètres PDO dans INTERVAL.
     *
     * On utilise donc une valeur entière contrôlée
     * directement dans la requête.
     */

    $attemptQuery = $pdo->prepare(
        'SELECT COUNT(*) AS failed_attempts
         FROM login_attempts
         WHERE success = 0
         AND attempted_at >= DATE_SUB(
             NOW(),
             INTERVAL 15 MINUTE
         )
         AND (
             email = :email
             OR ip_address = :ip_address
         )'
    );


    $attemptQuery->execute(
        [
            ':email'      => $email,
            ':ip_address' => $ipAddress,
        ]
    );


    $attemptData = $attemptQuery->fetch();

    $failedAttempts = (int)(
        $attemptData['failed_attempts'] ?? 0
    );


    if ($failedAttempts >= $maxFailedAttempts) {

        sendJson(
            false,
            'Trop de tentatives de connexion. Veuillez réessayer plus tard.',
            [],
            429
        );
    }


    /*
    |--------------------------------------------------------------------------
    | Find user
    |--------------------------------------------------------------------------
    */

    $userQuery = $pdo->prepare(
        'SELECT
            id,
            first_name,
            last_name,
            email,
            password_hash,
            status,
            account_type,
            preferred_language
         FROM users
         WHERE email = :email
         LIMIT 1'
    );


    $userQuery->execute(
        [
            ':email' => $email,
        ]
    );


    $user = $userQuery->fetch();


    /*
    |--------------------------------------------------------------------------
    | Generic authentication failure
    |--------------------------------------------------------------------------
    |
    | Ne jamais révéler si l'adresse e-mail existe.
    |
    */

    if (!$user) {

        $logAttempt = $pdo->prepare(
            'INSERT INTO login_attempts
            (
                user_id,
                email,
                ip_address,
                success
            )
            VALUES
            (
                NULL,
                :email,
                :ip_address,
                0
            )'
        );


        $logAttempt->execute(
            [
                ':email'      => $email,
                ':ip_address' => $ipAddress,
            ]
        );


        sendJson(
            false,
            'Adresse e-mail ou mot de passe incorrect.',
            [],
            401
        );
    }


    /*
    |--------------------------------------------------------------------------
    | Account status
    |--------------------------------------------------------------------------
    */

    if ($user['status'] !== 'active') {

        $logAttempt = $pdo->prepare(
            'INSERT INTO login_attempts
            (
                user_id,
                email,
                ip_address,
                success
            )
            VALUES
            (
                :user_id,
                :email,
                :ip_address,
                0
            )'
        );


        $logAttempt->execute(
            [
                ':user_id'    => $user['id'],
                ':email'      => $email,
                ':ip_address' => $ipAddress,
            ]
        );


        sendJson(
            false,
            'Adresse e-mail ou mot de passe incorrect.',
            [],
            401
        );
    }


    /*
    |--------------------------------------------------------------------------
    | Verify password
    |--------------------------------------------------------------------------
    */

    if (
        !password_verify(
            $password,
            $user['password_hash']
        )
    ) {

        $logAttempt = $pdo->prepare(
            'INSERT INTO login_attempts
            (
                user_id,
                email,
                ip_address,
                success
            )
            VALUES
            (
                :user_id,
                :email,
                :ip_address,
                0
            )'
        );


        $logAttempt->execute(
            [
                ':user_id'    => $user['id'],
                ':email'      => $email,
                ':ip_address' => $ipAddress,
            ]
        );


        sendJson(
            false,
            'Adresse e-mail ou mot de passe incorrect.',
            [],
            401
        );
    }


    /*
    |--------------------------------------------------------------------------
    | Password rehash
    |--------------------------------------------------------------------------
    */

    if (
        password_needs_rehash(
            $user['password_hash'],
            PASSWORD_DEFAULT
        )
    ) {

        $newPasswordHash = password_hash(
            $password,
            PASSWORD_DEFAULT
        );


        if ($newPasswordHash !== false) {

            $updatePassword = $pdo->prepare(
                'UPDATE users
                 SET password_hash = :password_hash
                 WHERE id = :user_id'
            );


            $updatePassword->execute(
                [
                    ':password_hash' => $newPasswordHash,
                    ':user_id'       => $user['id'],
                ]
            );
        }
    }


    /*
    |--------------------------------------------------------------------------
    | Generate session
    |--------------------------------------------------------------------------
    */

    $sessionId = sprintf(
        '%s-%s-%s-%s-%s',
        bin2hex(random_bytes(4)),
        bin2hex(random_bytes(2)),
        bin2hex(random_bytes(2)),
        bin2hex(random_bytes(2)),
        bin2hex(random_bytes(6))
    );


    /*
    | Raw token is sent to the frontend.
    | Only its SHA-256 hash is stored in database.
    */

    $rawToken = bin2hex(
        random_bytes(32)
    );


    $tokenHash = hash(
        'sha256',
        $rawToken
    );


    /*
    |--------------------------------------------------------------------------
    | Session expiration
    |--------------------------------------------------------------------------
    */

    $expiresAt = (new DateTimeImmutable(
        '+7 days'
    ))->format(
        'Y-m-d H:i:s'
    );


    /*
    |--------------------------------------------------------------------------
    | Transaction
    |--------------------------------------------------------------------------
    */

    $pdo->beginTransaction();


    /*
    |--------------------------------------------------------------------------
    | Create session
    |--------------------------------------------------------------------------
    */

    $sessionInsert = $pdo->prepare(
        'INSERT INTO sessions
        (
            id,
            user_id,
            token_hash,
            ip_address,
            user_agent,
            expires_at
        )
        VALUES
        (
            :id,
            :user_id,
            :token_hash,
            :ip_address,
            :user_agent,
            :expires_at
        )'
    );


    $sessionInsert->execute(
        [
            ':id'         => $sessionId,
            ':user_id'    => $user['id'],
            ':token_hash' => $tokenHash,
            ':ip_address' => $ipAddress,
            ':user_agent' => $userAgent,
            ':expires_at' => $expiresAt,
        ]
    );


    /*
    |--------------------------------------------------------------------------
    | Update last login
    |--------------------------------------------------------------------------
    */

    $updateLogin = $pdo->prepare(
        'UPDATE users
         SET last_login_at = NOW()
         WHERE id = :user_id'
    );


    $updateLogin->execute(
        [
            ':user_id' => $user['id'],
        ]
    );


    /*
    |--------------------------------------------------------------------------
    | Successful login attempt
    |--------------------------------------------------------------------------
    */

    $logSuccess = $pdo->prepare(
        'INSERT INTO login_attempts
        (
            user_id,
            email,
            ip_address,
            success
        )
        VALUES
        (
            :user_id,
            :email,
            :ip_address,
            1
        )'
    );


    $logSuccess->execute(
        [
            ':user_id'    => $user['id'],
            ':email'      => $email,
            ':ip_address' => $ipAddress,
        ]
    );


    /*
    |--------------------------------------------------------------------------
    | Audit log
    |--------------------------------------------------------------------------
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
            ':user_id'     => $user['id'],
            ':action'      => 'USER_LOGIN',
            ':entity_type' => 'user',
            ':entity_id'   => $user['id'],
            ':ip_address'  => $ipAddress,
        ]
    );


    /*
    |--------------------------------------------------------------------------
    | Commit
    |--------------------------------------------------------------------------
    */

    $pdo->commit();


    /*
    |--------------------------------------------------------------------------
    | Success response
    |--------------------------------------------------------------------------
    */

    sendJson(
        true,
        'Connexion réussie.',
        [
            'user' => [
                'id'                 => $user['id'],
                'first_name'         => $user['first_name'],
                'last_name'          => $user['last_name'],
                'email'              => $user['email'],
                'status'             => $user['status'],
                'account_type'       => $user['account_type'],
                'preferred_language' => $user['preferred_language'],
            ],

            'session' => [
                'id'         => $sessionId,
                'token'      => $rawToken,
                'expires_at' => $expiresAt,
            ],
        ],
        200
    );


} catch (Throwable $exception) {

    if (
        $pdo instanceof PDO &&
        $pdo->inTransaction()
    ) {
        $pdo->rollBack();
    }


    error_log(
        'DeepRDMMakademy login error: ' .
        $exception->getMessage()
    );


    sendJson(
        false,
        'Une erreur est survenue lors de la connexion.',
        [],
        500
    );
}
