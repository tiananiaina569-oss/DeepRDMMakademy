<?php

declare(strict_types=1);

/**
 * ============================================================
 * DeepRDMMakademy
 * Database Configuration
 * ============================================================
 *
 * PHP 8.x
 * MySQL / MariaDB
 *
 * IMPORTANT :
 * Remplacer uniquement les valeurs YOUR_DATABASE_* par
 * les véritables informations MySQL fournies par Hostinger.
 * ============================================================
 */

const DB_HOST = 'localhost';

const DB_NAME = 'YOUR_DATABASE_NAME';

const DB_USER = 'YOUR_DATABASE_USER';

const DB_PASS = 'YOUR_DATABASE_PASSWORD';

const DB_CHARSET = 'utf8mb4';


/**
 * ============================================================
 * Database connection
 * ============================================================
 */

function getDatabaseConnection(): PDO
{
    static $pdo = null;

    /*
     * Réutiliser la connexion existante pendant la requête.
     */
    if ($pdo instanceof PDO) {
        return $pdo;
    }

    /*
     * Construction du DSN.
     */
    $dsn =
        'mysql:host=' . DB_HOST .
        ';dbname=' . DB_NAME .
        ';charset=' . DB_CHARSET;


    /*
     * Options PDO.
     */
    $options = [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
        PDO::ATTR_STRINGIFY_FETCHES  => false,
    ];


    /*
     * Connexion.
     */
    try {

        $pdo = new PDO(
            $dsn,
            DB_USER,
            DB_PASS,
            $options
        );

        return $pdo;

    } catch (PDOException $exception) {

        /*
         * Ne jamais exposer les détails de connexion
         * ou les erreurs SQL à l'utilisateur.
         */
        error_log(
            'DeepRDMMakademy database connection error: ' .
            $exception->getMessage()
        );

        http_response_code(500);

        header(
            'Content-Type: application/json; charset=utf-8'
        );

        echo json_encode(
            [
                'success' => false,
                'message' => 'Database connection failed.'
            ],
            JSON_UNESCAPED_UNICODE |
            JSON_UNESCAPED_SLASHES
        );

        exit;
    }
}
