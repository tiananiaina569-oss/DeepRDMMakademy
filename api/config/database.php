<?php

declare(strict_types=1);

/*
|--------------------------------------------------------------------------
| DeepRDMMakademy
| Database configuration
|--------------------------------------------------------------------------
|
| IMPORTANT:
| Replace the values below with the MySQL credentials provided by Hostinger.
|
| Do NOT commit real production credentials to GitHub.
|
*/

const DB_HOST = 'localhost';
const DB_NAME = 'deeprdmmakademy';
const DB_USER = 'YOUR_DATABASE_USER';
const DB_PASS = 'YOUR_DATABASE_PASSWORD';

function getDatabaseConnection(): PDO
{
    static $pdo = null;

    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $dsn = 'mysql:host=' . DB_HOST .
           ';dbname=' . DB_NAME .
           ';charset=utf8mb4';

    $options = [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
    ];

    try {
        $pdo = new PDO(
            $dsn,
            DB_USER,
            DB_PASS,
            $options
        );

        return $pdo;

    } catch (PDOException $exception) {

        error_log(
            'DeepRDMMakademy database connection error: ' .
            $exception->getMessage()
        );

        http_response_code(500);

        header('Content-Type: application/json; charset=utf-8');

        echo json_encode([
            'success' => false,
            'message' => 'Database connection failed.'
        ]);

        exit;
    }
}
