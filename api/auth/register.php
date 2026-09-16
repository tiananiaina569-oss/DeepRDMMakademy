<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

header(
    'Access-Control-Allow-Origin: https://tiananiaina569-oss.github.io'
);

header(
    'Access-Control-Allow-Methods: POST, OPTIONS'
);

header(
    'Access-Control-Allow-Headers: Content-Type'
);

header(
    'Access-Control-Allow-Credentials: true'
);

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);

    echo json_encode([
        'success' => false,
        'message' => 'Method not allowed.'
    ]);

    exit;
}

require_once __DIR__ . '/../config/database.php';

function respond(
    bool $success,
    string $message,
    int $statusCode = 200,
    array $extra = []
): void {

    http_response_code($statusCode);

    echo json_encode(
        array_merge(
            [
                'success' => $success,
                'message' => $message
            ],
            $extra
        ),
        JSON_UNESCAPED_UNICODE
    );

    exit;
}

$rawInput = file_get_contents('php://input');

if ($rawInput === false || trim($rawInput) === '') {
    respond(
        false,
        'Données de création de compte manquantes.',
        400
    );
}

$data = json_decode($rawInput, true);

if (!is_array($data)) {
    respond(
        false,
        'Format de données invalide.',
        400
    );
}

$firstName = trim((string)($data['first_name'] ?? ''));
$lastName = trim((string)($data['last_name'] ?? ''));
$email = strtolower(trim((string)($data['email'] ?? '')));
$country = trim((string)($data['country'] ?? ''));
$currentLevel = trim((string)($data['current_level'] ?? ''));
$password = (string)($data['password'] ?? '');

if (
    $firstName === '' ||
    $lastName === '' ||
    $email === '' ||
    $password === ''
) {
    respond(
        false,
        'Veuillez remplir tous les champs obligatoires.',
        422
    );
}

if (
    mb_strlen($firstName) > 100 ||
    mb_strlen($lastName) > 100
) {
    respond(
        false,
        'Nom ou prénom trop long.',
        422
    );
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    respond(
        false,
        'Adresse email invalide.',
        422
    );
}

if (mb_strlen($email) > 190) {
    respond(
        false,
        'Adresse email trop longue.',
        422
    );
}

if (strlen($password) < 10) {
    respond(
        false,
        'Le mot de passe doit contenir au moins 10 caractères.',
        422
    );
}

if (strlen($password) > 255) {
    respond(
        false,
        'Mot de passe trop long.',
        422
    );
}

try {

    $pdo = getDatabaseConnection();

    $checkStatement = $pdo->prepare(
        'SELECT id FROM users WHERE email = :email LIMIT 1'
    );

    $checkStatement->execute([
        ':email' => $email
    ]);

    if ($checkStatement->fetch()) {
        respond(
            false,
            'Un compte existe déjà avec cette adresse email.',
            409
        );
    }

    $uuid = sprintf(
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

    $passwordHash = password_hash(
        $password,
        PASSWORD_DEFAULT
    );

    if ($passwordHash === false) {
        respond(
            false,
            'Impossible de sécuriser le mot de passe.',
            500
        );
    }

    $pdo->beginTransaction();

    $insertUser = $pdo->prepare(
        'INSERT INTO users (
            uuid,
            first_name,
            last_name,
            email,
            country,
            current_level,
            requested_level,
            password_hash,
            status
        )
        VALUES (
            :uuid,
            :first_name,
            :last_name,
            :email,
            :country,
            :current_level,
            :requested_level,
            :password_hash,
            :status
        )'
    );

    $insertUser->execute([
        ':uuid' => $uuid,
        ':first_name' => $firstName,
        ':last_name' => $lastName,
        ':email' => $email,
        ':country' => $country !== '' ? $country : null,
        ':current_level' => $currentLevel !== '' ? $currentLevel : null,
        ':requested_level' => $currentLevel !== '' ? $currentLevel : null,
        ':password_hash' => $passwordHash,
        ':status' => 'active'
    ]);

    $userId = (int)$pdo->lastInsertId();

    $roleStatement = $pdo->prepare(
        'SELECT id
         FROM roles
         WHERE name = :role
         LIMIT 1'
    );

    $roleStatement->execute([
        ':role' => 'student'
    ]);

    $role = $roleStatement->fetch();

    if (!$role) {
        throw new RuntimeException(
            'Default student role does not exist.'
        );
    }

    $assignRole = $pdo->prepare(
        'INSERT INTO user_roles (
            user_id,
            role_id
        )
        VALUES (
            :user_id,
            :role_id
        )'
    );

    $assignRole->execute([
        ':user_id' => $userId,
        ':role_id' => (int)$role['id']
    ]);

    $auditStatement = $pdo->prepare(
        'INSERT INTO audit_logs (
            user_id,
            action,
            entity_type,
            entity_id,
            ip_address,
            details
        )
        VALUES (
            :user_id,
            :action,
            :entity_type,
            :entity_id,
            :ip_address,
            :details
        )'
    );

    $auditStatement->execute([
        ':user_id' => $userId,
        ':action' => 'account.created',
        ':entity_type' => 'user',
        ':entity_id' => $userId,
        ':ip_address' => $_SERVER['REMOTE_ADDR'] ?? null,
        ':details' => json_encode([
            'source' => 'register_api'
        ])
    ]);

    $pdo->commit();

    respond(
        true,
        'Compte DeepRDMMakademy créé avec succès.',
        201,
        [
            'user' => [
                'id' => $userId,
                'uuid' => $uuid,
                'first_name' => $firstName,
                'last_name' => $lastName,
                'email' => $email,
                'status' => 'active',
                'role' => 'student'
            ]
        ]
    );

} catch (Throwable $exception) {

    if (
        isset($pdo) &&
        $pdo instanceof PDO &&
        $pdo->inTransaction()
    ) {
        $pdo->rollBack();
    }

    error_log(
        'DeepRDMMakademy registration error: ' .
        $exception->getMessage()
    );

    respond(
        false,
        'Une erreur est survenue pendant la création du compte.',
        500
    );
}
