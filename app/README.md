Simple PHP app that records students (student ID + name) into a MySQL-compatible database (RDS).

Environment variables used by the app (set on the EC2 instance or in the webserver environment):

- DB_HOST - database host (required)
- DB_PORT - database port (optional, default 3306)
- DB_NAME - database name (optional, default students_db)
- DB_USER - database user (required)
- DB_PASS - database password (required)

How it works:
- The app's PHP code is in `index.php` and `db.php`.
- On first access, the app will attempt to create the database/table using `create_table.sql`.

Recommended Terraform wiring:
- Create an RDS MySQL instance and output the endpoint, port, and credentials as output variables.
- Configure the EC2 `user_data.sh` to export DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASS into `/etc/profile.d/app_env.sh` or write them into `/etc/environment`.
- Ensure the EC2 security group allows outbound access to RDS and the RDS security group allows inbound from the EC2 security group.

Notes:
- This is a minimal example for demo/testing. For production, use secrets manager for DB credentials, TLS for connections, input validation, and prepared statements (already used here) and proper error handling.
