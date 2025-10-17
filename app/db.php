<?php
// DB wrapper that prefers fetching credentials from Secrets Manager at runtime via the AWS SDK.
// Falls back to environment variables if the SDK isn't available or DB_SECRET_ARN is not set.

function fetch_db_secret(string $secretArn): array
{
    static $cached = null;
    if ($cached !== null) {
        return $cached;
    }

    // Attempt to load AWS SDK autoloader if present
    $autoload = __DIR__ . '/vendor/autoload.php';
    if (file_exists($autoload)) {
        require_once $autoload;
    }

    try {
        if (!class_exists('\Aws\SecretsManager\SecretsManagerClient')) {
            throw new Exception('AWS SDK not available');
        }

        $client = new \Aws\SecretsManager\SecretsManagerClient([
            'version' => 'latest',
            'region'  => getenv('AWS_REGION') ?: 'us-east-1',
        ]);

        $result = $client->getSecretValue(['SecretId' => $secretArn]);
        $secretString = $result['SecretString'] ?? '{}';
        $data = json_decode($secretString, true);
        if (!is_array($data)) {
            throw new Exception('Invalid secret JSON');
        }
        $cached = $data;
        return $data;
    } catch (Exception $e) {
        // Fall back to environment variables if anything goes wrong
        return [];
    }
}

function get_db_config(): array
{
    static $cfg = null;
    if ($cfg !== null) return $cfg;

    $secretArn = getenv('DB_SECRET_ARN') ?: null;
    if ($secretArn) {
        $data = fetch_db_secret($secretArn);
        if (!empty($data)) {
            $cfg = [
                'host' => $data['host'] ?? getenv('DB_HOST') ?: '127.0.0.1',
                'port' => $data['port'] ?? getenv('DB_PORT') ?: 3306,
                'name' => $data['db_name'] ?? getenv('DB_NAME') ?: 'students_db',
                'user' => $data['username'] ?? getenv('DB_USER') ?: 'root',
                'pass' => $data['password'] ?? getenv('DB_PASS') ?: '',
            ];
            return $cfg;
        }
    }

    // Fallback to environment variables
    $cfg = [
        'host' => getenv('DB_HOST') ?: '127.0.0.1',
        'port' => getenv('DB_PORT') ?: 3306,
        'name' => getenv('DB_NAME') ?: 'students_db',
        'user' => getenv('DB_USER') ?: 'root',
        'pass' => getenv('DB_PASS') ?: '',
    ];
    return $cfg;
}

function get_mysqli(): mysqli
{
    $c = get_db_config();
    $mysqli = new mysqli($c['host'], $c['user'], $c['pass'], $c['name'], intval($c['port']));
    if ($mysqli->connect_error) {
        throw new Exception('DB connect error: ' . $mysqli->connect_error);
    }
    $mysqli->set_charset('utf8mb4');
    return $mysqli;
}

function ensure_table_exists(): void
{
    $sql = file_get_contents(__DIR__ . '/create_table.sql');
    if ($sql === false) {
        throw new Exception('Missing create_table.sql');
    }
    $db = get_mysqli();
    if (!$db->multi_query($sql)) {
        $err = $db->error;
        while ($db->more_results() && $db->next_result()) { }
        if (stripos($err, 'already exists') === false) {
            throw new Exception('Error creating table: ' . $err);
        }
    }
    $db->close();
}

function insert_student(string $student_id, string $name): void
{
    $db = get_mysqli();
    $stmt = $db->prepare('INSERT INTO students (student_id, name) VALUES (?, ?)');
    if (!$stmt) {
        throw new Exception('Prepare failed: ' . $db->error);
    }
    $stmt->bind_param('ss', $student_id, $name);
    if (!$stmt->execute()) {
        $err = $stmt->error;
        $stmt->close();
        $db->close();
        throw new Exception('Execute failed: ' . $err);
    }
    $stmt->close();
    $db->close();
}

function get_students(): array
{
    try {
        ensure_table_exists();
    } catch (Exception $e) {
    }

    $db = get_mysqli();
    $res = $db->query('SELECT student_id, name, created_at FROM students ORDER BY created_at DESC LIMIT 100');
    if (!$res) {
        $err = $db->error;
        $db->close();
        throw new Exception('Query failed: ' . $err);
    }
    $rows = [];
    while ($r = $res->fetch_assoc()) {
        $rows[] = $r;
    }
    $res->free();
    $db->close();
    return $rows;
}
<?php
// Simple DB wrapper using mysqli and environment variables.

function get_db_config(): array
{
    $cfg = [
        'host' => getenv('DB_HOST') ?: '127.0.0.1',
        'port' => getenv('DB_PORT') ?: 3306,
        'name' => getenv('DB_NAME') ?: 'students_db',
        'user' => getenv('DB_USER') ?: 'root',
        'pass' => getenv('DB_PASS') ?: '',
    ];
    return $cfg;
}

function get_mysqli(): mysqli
{
    $c = get_db_config();
    $mysqli = new mysqli($c['host'], $c['user'], $c['pass'], $c['name'], intval($c['port']));
    if ($mysqli->connect_error) {
        throw new Exception('DB connect error: ' . $mysqli->connect_error);
    }
    $mysqli->set_charset('utf8mb4');
    return $mysqli;
}

function ensure_table_exists(): void
{
    $sql = file_get_contents(__DIR__ . '/create_table.sql');
    if ($sql === false) {
        throw new Exception('Missing create_table.sql');
    }
    $db = get_mysqli();
    if (!$db->multi_query($sql)) {
        // If table already exists or other benign error occurs, ignore if it's only duplicate
        // Otherwise, throw
        $err = $db->error;
        // consume results
        while ($db->more_results() && $db->next_result()) { }
        if (stripos($err, 'already exists') === false) {
            throw new Exception('Error creating table: ' . $err);
        }
    }
    $db->close();
}

function insert_student(string $student_id, string $name): void
{
    $db = get_mysqli();
    $stmt = $db->prepare('INSERT INTO students (student_id, name) VALUES (?, ?)');
    if (!$stmt) {
        throw new Exception('Prepare failed: ' . $db->error);
    }
    $stmt->bind_param('ss', $student_id, $name);
    if (!$stmt->execute()) {
        $err = $stmt->error;
        $stmt->close();
        $db->close();
        throw new Exception('Execute failed: ' . $err);
    }
    $stmt->close();
    $db->close();
}

function get_students(): array
{
    // Ensure table exists (no-op if it already does)
    try {
        ensure_table_exists();
    } catch (Exception $e) {
        // Bubble up — caller will handle
    }

    $db = get_mysqli();
    $res = $db->query('SELECT student_id, name, created_at FROM students ORDER BY created_at DESC LIMIT 100');
    if (!$res) {
        $err = $db->error;
        $db->close();
        throw new Exception('Query failed: ' . $err);
    }
    $rows = [];
    while ($r = $res->fetch_assoc()) {
        $rows[] = $r;
    }
    $res->free();
    $db->close();
    return $rows;
}
