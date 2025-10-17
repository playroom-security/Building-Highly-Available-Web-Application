#!/bin/bash
# Building a simple website that stores the students names and IDS in a RDS database

# Update and install necessary packages
apt-get update -y
apt-get install -y nginx git
apt-get install -y mysql-client
apt-get install -y php-fpm php-mysql php-cli php-curl php-json php-mbstring php-xml php-zip



# Start and enable Nginx
systemctl start nginx
systemctl enable nginx

# Create web app directory and write PHP app files (index.php, db.php, create_table.sql)
mkdir -p /var/www/html/app

cat >/var/www/html/app/index.php <<'PHP_APP'
<?php
require_once __DIR__ . '/db.php';

$error = null;
$success = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
		$student_id = trim($_POST['student_id'] ?? '');
		$name = trim($_POST['name'] ?? '');

		if ($student_id === '' || $name === '') {
				$error = 'Both Student ID and Name are required.';
		} else {
				try {
						insert_student($student_id, $name);
						$success = 'Student saved.';
				} catch (Exception $e) {
						$error = 'Error saving student: ' . $e->getMessage();
				}
		}
}

$students = [];
try {
		$students = get_students();
} catch (Exception $e) {
		$error = ($error ? $error . ' | ' : '') . 'Error loading students: ' . $e->getMessage();
}
?>
<!doctype html>
<html lang="en">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width,initial-scale=1">
	<title>Students</title>
	<style>
		body { font-family: Arial, Helvetica, sans-serif; max-width: 900px; margin: 40px auto; }
		form { margin-bottom: 20px; }
		input[type=text] { padding: 8px; width: 250px; }
		table { border-collapse: collapse; width: 100%; }
		th, td { border: 1px solid #ddd; padding: 8px; }
		th { background: #f4f4f4; }
		.ok { color: green; }
		.err { color: red; }
	</style>
</head>
<body>
	<h1>Students</h1>

	<?php if ($error): ?>
		<p class="err"><?= htmlspecialchars($error) ?></p>
	<?php endif; ?>

	<?php if ($success): ?>
		<p class="ok"><?= htmlspecialchars($success) ?></p>
	<?php endif; ?>

	<form method="post">
		<label>Student ID<br>
			<input type="text" name="student_id" required>
		</label>
		&nbsp;
		<label>Name<br>
			<input type="text" name="name" required>
		</label>
		&nbsp;
		<button type="submit">Save</button>
	</form>

	<h2>Saved students</h2>
	<table>
		<thead>
			<tr><th>#</th><th>Student ID</th><th>Name</th><th>Created</th></tr>
		</thead>
		<tbody>
		<?php foreach ($students as $i => $s): ?>
			<tr>
				<td><?= $i + 1 ?></td>
				<td><?= htmlspecialchars($s['student_id']) ?></td>
				<td><?= htmlspecialchars($s['name']) ?></td>
				<td><?= htmlspecialchars($s['created_at']) ?></td>
			</tr>
		<?php endforeach; ?>
		</tbody>
	</table>
</body>
</html>
PHP_APP

cat >/var/www/html/app/db.php <<'PHP_DB'
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
		if (!class_exists('\\Aws\\SecretsManager\\SecretsManagerClient')) {
			throw new Exception('AWS SDK not available');
		}

		$client = new \\Aws\\SecretsManager\\SecretsManagerClient([
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
PHP_DB

cat >/var/www/html/app/create_table.sql <<'SQL'
-- SQL to create students table
CREATE DATABASE IF NOT EXISTS students_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE students_db;

CREATE TABLE IF NOT EXISTS students (
	id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
	student_id VARCHAR(128) NOT NULL,
	name VARCHAR(255) NOT NULL,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	PRIMARY KEY (id),
	UNIQUE KEY uq_student_id (student_id)
);
SQL

chown -R www-data:www-data /var/www/html/app

# Install Composer (if not present) and the AWS SDK for PHP
if ! command -v composer >/dev/null 2>&1; then
	EXPECTED_CHECKSUM="" # optional: pin checksum
	php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" || true
	php composer-setup.php --install-dir=/usr/local/bin --filename=composer || true
	php -r "unlink('composer-setup.php');" || true
fi

cd /var/www/html/app || exit 0
if [ ! -f composer.json ]; then
	/usr/local/bin/composer init --no-interaction --name="playroom/students-app" || true
fi
/usr/local/bin/composer require aws/aws-sdk-php:^3.0 --no-interaction || true

chown -R www-data:www-data /var/www/html/app

# Install amazon-efs-utils for mounting EFS
apt-get update -y || true
apt-get install -y amazon-efs-utils nfs-common || true

# Mount EFS if EFS_ID available
EFS_ID=$(grep EFS_ID /etc/profile.d/app_env.sh 2>/dev/null | cut -d'=' -f2 | tr -d '"') || true
if [ -n "$EFS_ID" ]; then
	mkdir -p /var/www/html/app/shared
	# mount using efs-utils (recommended) and persist to fstab
	echo "${EFS_ID}:/ /var/www/html/app/shared efs defaults,_netdev 0 0" >> /etc/fstab || true
	mount -a || true
		# Ensure the mounted EFS directory is owned by the webserver user so PHP can write to it
		chown -R www-data:www-data /var/www/html/app/shared || true
fi

# Configure Nginx site to serve the app at root /app
cat >/etc/nginx/sites-available/app.conf <<'NGINX'
server {
		listen 80 default_server;
		listen [::]:80 default_server;

		root /var/www/html/app;
		index index.php index.html index.htm;

		server_name _;

		location / {
				try_files $uri $uri/ /index.php?$query_string;
		}

		location ~ \.php$ {
				include snippets/fastcgi-php.conf;
				# Depending on the php-fpm version the socket path may vary. Use the default unix socket.
				fastcgi_pass unix:/run/php/php-fpm.sock;
		}

		location ~ /\.ht {
				deny all;
		}
}
NGINX

ln -sf /etc/nginx/sites-available/app.conf /etc/nginx/sites-enabled/app.conf || true
rm -f /etc/nginx/sites-enabled/default || true

# Restart/reload services to pick up site and PHP-FPM
systemctl restart php*-fpm || true
systemctl restart nginx || true

# If DB environment variables are present, attempt to run the SQL to create DB/table now
if [ -n "$DB_HOST" ] && [ -n "$DB_USER" ]; then
	echo "DB env detected, attempting initial DB create..."
	# Create a temp .sql file and run it with the mysql client
	if [ -f /var/www/html/app/create_table.sql ]; then
		mysql -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USER" -p"$DB_PASS" < /var/www/html/app/create_table.sql || true
	fi
fi

