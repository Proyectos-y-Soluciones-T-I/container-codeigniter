<?php
/**
 * Dashboard Visual de Proyectos
 *
 * Self-contained PHP dashboard that auto-discovers projects in src/
 * and renders them as a responsive card grid with dark theme.
 *
 * No JS, no external dependencies — pure PHP 7.4+ inline CSS.
 */

// --- Configuration ---
$docRoot = '/var/www/html';
$self    = basename(__FILE__);
$projects = [];
$error    = null;

// --- Scan & Filter Projects ---
$entries = scandir($docRoot);

if ($entries === false) {
    // src/ is not readable at all — return 500
    http_response_code(500);
    $error = 'Unable to read projects directory.';
} else {
    foreach ($entries as $entry) {
        // Skip dotfiles, dots, current dir, parent dir
        if ($entry[0] === '.') {
            continue;
        }

        $path = $docRoot . '/' . $entry;

        // Only directories; skip files and our own script
        if (!is_dir($path)) {
            continue;
        }
        if ($entry === $self) {
            continue;
        }

        // Silently skip unreadable directories (filemtime returns false)
        $mtime = @filemtime($path);
        if ($mtime === false) {
            continue;
        }

        $hasLogo = file_exists($path . '/logo.png');
        $projects[] = [$entry, $hasLogo, $mtime];
    }

    sort($projects);
}

// --- Helper ---
function humanize(string $name): string
{
    return ucwords(str_replace(['-', '_'], ' ', $name));
}
?><!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Proyectos - Dashboard</title>
<style>
/* === Design Tokens (Slate Dark Palette) === */
:root {
    --bg:         #0f1729;
    --card-bg:    #1e293b;
    --border:     #334155;
    --accent:     #3b82f6;
    --text:       #e2e8f0;
    --text-muted: #94a3b8;
    --radius:     12px;
}

/* === Reset === */
*, *::before, *::after {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto,
                 Oxygen, Ubuntu, Cantarell, sans-serif;
    background: var(--bg);
    color: var(--text);
    min-height: 100vh;
    padding: 2rem;
}

/* === Header === */
header {
    margin-bottom: 2rem;
}

header h1 {
    font-size: 1.5rem;
    font-weight: 700;
    letter-spacing: -0.02em;
}

header p {
    color: var(--text-muted);
    margin-top: 0.25rem;
    font-size: 0.95rem;
}

/* === Card Grid === */
.grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 1.5rem;
}

/* === Card === */
.card {
    background: var(--card-bg);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    overflow: hidden;
    transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.card:hover {
    transform: translateY(-3px);
    box-shadow: 0 8px 28px rgba(0, 0, 0, 0.35);
}

/* Logo area */
.card-logo {
    width: 100%;
    height: 120px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--bg);
    padding: 1rem;
}

.card-logo img {
    max-width: 80%;
    max-height: 80%;
    object-fit: contain;
}

/* Fallback letter when no logo.png exists */
.logo-fallback {
    width: 64px;
    height: 64px;
    border-radius: 8px;
    background: var(--accent);
    color: #ffffff;
    font-size: 1.5rem;
    font-weight: 700;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
}

/* Card body */
.card-body {
    padding: 1rem 1.25rem 1.25rem;
}

.card-body h2 {
    font-size: 1.05rem;
    font-weight: 600;
    margin-bottom: 0.35rem;
    line-height: 1.3;
}

.card-body .date {
    font-size: 0.8rem;
    color: var(--text-muted);
    margin-bottom: 0.75rem;
}

.card-body .link {
    display: inline-block;
    padding: 0.4rem 1rem;
    background: var(--accent);
    color: #ffffff;
    text-decoration: none;
    border-radius: 6px;
    font-size: 0.85rem;
    font-weight: 500;
    transition: opacity 0.15s ease;
}

.card-body .link:hover {
    opacity: 0.85;
}

.card-body .link:focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: 2px;
}

/* === Empty State === */
.empty {
    grid-column: 1 / -1;
    text-align: center;
    padding: 4rem 2rem;
    color: var(--text-muted);
}

.empty p {
    font-size: 1.1rem;
    line-height: 1.6;
}

/* === Error State === */
.error {
    grid-column: 1 / -1;
    text-align: center;
    padding: 4rem 2rem;
    color: #ef4444;
}

/* === Responsive: single column on mobile === */
@media (max-width: 640px) {
    body {
        padding: 1rem;
    }

    .grid {
        grid-template-columns: 1fr;
        gap: 1rem;
    }

    header h1 {
        font-size: 1.25rem;
    }
}
</style>
</head>
<body>

<header>
    <h1>Proyectos</h1>
    <p>Selecciona un proyecto para comenzar</p>
</header>

<main class="grid">

<?php if ($error): ?>
    <div class="error">
        <p><?= htmlspecialchars($error, ENT_QUOTES, 'UTF-8') ?></p>
    </div>

<?php elseif (empty($projects)): ?>
    <div class="empty">
        <p>No projects found. Add a project to <code>src/</code> to get started.</p>
    </div>

<?php else: ?>
    <?php foreach ($projects as $proj):
        [$name, $hasLogo, $mtime] = $proj;
        $safeName   = htmlspecialchars($name, ENT_QUOTES, 'UTF-8');
        $humanName  = htmlspecialchars(humanize($name), ENT_QUOTES, 'UTF-8');
        $firstChar  = htmlspecialchars(mb_strtoupper($name[0]), ENT_QUOTES, 'UTF-8');
        $dateStr    = htmlspecialchars(date('Y-m-d', $mtime), ENT_QUOTES, 'UTF-8');
    ?>
    <article class="card">
        <div class="card-logo">
            <?php if ($hasLogo): ?>
            <img src="/<?= $safeName ?>/logo.png"
                 alt="<?= $humanName ?> logo"
                 loading="lazy">
            <?php else: ?>
            <div class="logo-fallback"><?= $firstChar ?></div>
            <?php endif; ?>
        </div>
        <div class="card-body">
            <h2><?= $humanName ?></h2>
            <p class="date"><?= $dateStr ?></p>
            <a class="link" href="/<?= $safeName ?>/">Abrir proyecto</a>
        </div>
    </article>
    <?php endforeach; ?>
<?php endif; ?>

</main>
</body>
</html>
