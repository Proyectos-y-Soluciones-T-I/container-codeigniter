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

        $logoFile = findLogo($path);
        $projects[] = [$entry, $logoFile, $mtime];
    }

    sort($projects);
}

// --- Helpers ---
function humanize(string $name): string
{
    return ucwords(str_replace(['-', '_'], ' ', $name));
}

/**
 * Scan a project directory for a logo/image file.
 * Returns the filename if found, or null if none.
 * Looks for: logo*, favicon*, icon*  with extensions: png, jpg, jpeg, gif, svg, ico, webp
 */
function findLogo(string $projectPath): ?string
{
    $patterns = ['logo*', 'favicon*', 'icon*'];
    $exts     = ['png', 'jpg', 'jpeg', 'gif', 'svg', 'ico', 'webp'];

    foreach ($patterns as $pattern) {
        foreach ($exts as $ext) {
            $files = glob($projectPath . '/' . $pattern . '.' . $ext, GLOB_NOSORT);
            if (!empty($files)) {
                return basename($files[0]);
            }
        }
    }

    return null;
}
?><!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Proyectos - Dashboard</title>
<style>
/* === Design Tokens (Clean Light Palette) === */
:root {
    --bg:         #f8f9fa;
    --card-bg:    #ffffff;
    --border:     #e2e8f0;
    --accent:     #4f8ef7;
    --accent-hover:#3b7de6;
    --text:       #1e293b;
    --text-muted: #64748b;
    --logo-area:  #f1f5f9;
    --shadow:     0 1px 3px rgba(0, 0, 0, 0.06), 0 1px 2px rgba(0, 0, 0, 0.04);
    --shadow-hover: 0 4px 16px rgba(0, 0, 0, 0.08);
    --radius:     10px;
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

/* === Header Bar === */
.header-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 1rem;
    margin-bottom: 2rem;
}

.header-bar h1 {
    font-size: 1.4rem;
    font-weight: 700;
    letter-spacing: -0.02em;
    color: var(--text);
}

.header-bar p {
    color: var(--text-muted);
    margin-top: 0.15rem;
    font-size: 0.9rem;
}

.header-actions {
    display: flex;
    gap: 0.6rem;
}

/* === Tool Buttons === */
.tool-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.5rem 1rem;
    background: var(--card-bg);
    border: 1px solid var(--border);
    border-radius: 8px;
    color: var(--text);
    text-decoration: none;
    font-size: 0.85rem;
    font-weight: 500;
    transition: background 0.15s ease, border-color 0.15s ease, box-shadow 0.15s ease;
    white-space: nowrap;
}

.tool-btn:hover {
    background: #eef2ff;
    border-color: var(--accent);
    box-shadow: 0 1px 3px rgba(79, 142, 247, 0.15);
}

.tool-btn:focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: 2px;
}

.tool-btn-icon {
    font-size: 1.1rem;
    line-height: 1;
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
    box-shadow: var(--shadow);
    transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.card:hover {
    transform: translateY(-2px);
    box-shadow: var(--shadow-hover);
}

/* Logo area */
.card-logo {
    width: 100%;
    height: 120px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--logo-area);
    padding: 1rem;
}

.card-logo img {
    max-width: 80%;
    max-height: 80%;
    object-fit: contain;
}

/* Fallback letter when no logo found */
.logo-fallback {
    width: 56px;
    height: 56px;
    border-radius: 8px;
    background: var(--accent);
    color: #ffffff;
    font-size: 1.4rem;
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
    font-size: 1rem;
    font-weight: 600;
    margin-bottom: 0.3rem;
    line-height: 1.3;
    color: var(--text);
}

.card-body .date {
    font-size: 0.78rem;
    color: var(--text-muted);
    margin-bottom: 0.75rem;
}

.card-body .link {
    display: inline-block;
    padding: 0.4rem 0.9rem;
    background: var(--accent);
    color: #ffffff;
    text-decoration: none;
    border-radius: 6px;
    font-size: 0.82rem;
    font-weight: 500;
    transition: background 0.15s ease;
}

.card-body .link:hover {
    background: var(--accent-hover);
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
    color: #dc2626;
}

/* === Responsive: single column on mobile === */
@media (max-width: 640px) {
    body {
        padding: 1rem;
    }

    .header-bar {
        flex-direction: column;
        align-items: flex-start;
    }

    .grid {
        grid-template-columns: 1fr;
        gap: 1rem;
    }
}
</style>
</head>
<body>

<header class="header-bar">
    <div>
        <h1>Proyectos</h1>
        <p>Selecciona un proyecto para comenzar</p>
    </div>
    <div class="header-actions">
        <a class="tool-btn" href="http://localhost:8081" target="_blank" rel="noopener">
            <span class="tool-btn-icon">🗄️</span> phpMyAdmin
        </a>
    </div>
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
        [$name, $logoFile, $mtime] = $proj;
        $safeName   = htmlspecialchars($name, ENT_QUOTES, 'UTF-8');
        $humanName  = htmlspecialchars(humanize($name), ENT_QUOTES, 'UTF-8');
        $firstChar  = htmlspecialchars(mb_strtoupper($name[0]), ENT_QUOTES, 'UTF-8');
        $dateStr    = htmlspecialchars(date('Y-m-d', $mtime), ENT_QUOTES, 'UTF-8');
    ?>
    <article class="card">
        <div class="card-logo">
            <?php if ($logoFile): ?>
            <img src="/<?= $safeName ?>/<?= htmlspecialchars($logoFile, ENT_QUOTES, 'UTF-8') ?>"
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
