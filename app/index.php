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
    $error = $error ? $error . ' | ' : '' . 'Error loading students: ' . $e->getMessage();
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
