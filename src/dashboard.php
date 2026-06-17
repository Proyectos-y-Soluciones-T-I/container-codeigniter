<?php
/**
 * Dashboard Visual de Proyectos
 *
 * Self-contained PHP dashboard that auto-discovers projects in src/
 * and renders them as a responsive card grid with Tailwind CSS.
 *
 * Dark-first theme with light toggle. No build step, no JS framework.
 * Uses Tailwind Play CDN with minimal fallback for offline use.
 */

// --- Configuration ---
$docRoot = '/var/www/html';
$self    = basename(__FILE__);
$projects = [];
$error    = null;

// --- Scan & Filter Projects ---
$entries = scandir($docRoot);

if ($entries === false) {
    http_response_code(500);
    $error = 'Unable to read projects directory.';
} else {
    foreach ($entries as $entry) {
        if ($entry[0] === '.') {
            continue;
        }

        $path = $docRoot . '/' . $entry;

        if (!is_dir($path)) {
            continue;
        }
        if ($entry === $self) {
            continue;
        }

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

// --- System Info ---
$phpVersion     = phpversion();
$serverSoftware = $_SERVER['SERVER_SOFTWARE'] ?? 'N/A';
$uploadMax      = ini_get('upload_max_filesize');
$opcacheEnabled = function_exists('opcache_get_status') && opcache_get_status() !== false;

$services = [
    'Nginx'      => 8888,
    'MariaDB'    => 3307,
    'phpMyAdmin' => 8081,
];

$trackedExtensions = ['pdo', 'pdo_mysql', 'mysqli', 'gd', 'zip', 'xml', 'mbstring', 'bcmath', 'opcache'];
$loadedExtensions  = get_loaded_extensions();
$extensionStatus   = [];
foreach ($trackedExtensions as $ext) {
    $extensionStatus[$ext] = in_array($ext, $loadedExtensions);
}
?><!DOCTYPE html>
<html lang="es" class="dark">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Proyectos - Dashboard</title>
<style>
/* ponytail: fallback CSS — usable when Tailwind CDN is offline */
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{--bg:#0f172a;--card:#1e293b;--border:#334155;--text:#e2e8f0;--muted:#94a3b8;--accent:#3b82f6;--accent2:#60a5fa;--green:#34d399}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:var(--bg);color:var(--text);min-height:100vh;padding:2rem}
main{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:1.5rem}
article{background:var(--card);border:1px solid var(--border);border-radius:12px;overflow:hidden;display:flex;flex-direction:column;transition:transform .2s,box-shadow .2s}
article:hover{transform:translateY(-2px);box-shadow:0 8px 24px rgba(0,0,0,.3)}
article a{color:var(--accent);text-decoration:none}
code{background:#334155;padding:.15rem .3rem;border-radius:3px;font-size:.85rem}
@media(max-width:640px){body{padding:1rem}main{grid-template-columns:1fr;gap:1rem}}
</style>
<script src="https://cdn.tailwindcss.com"></script>
<script>
tailwind.config = { darkMode: 'class' }
</script>
</head>
<body class="bg-slate-50 dark:bg-slate-950 text-slate-800 dark:text-slate-100 font-sans min-h-screen p-4 sm:p-8 transition-colors duration-300">

<header class="flex items-center justify-between flex-wrap gap-4 mb-8">
    <div>
        <h1 class="text-2xl font-bold tracking-tight text-slate-800 dark:text-white">Proyectos</h1>
        <p class="text-sm text-slate-500 dark:text-slate-400 mt-0.5">Selecciona un proyecto para comenzar</p>
    </div>
    <div class="flex items-center gap-2.5">
        <button id="theme-toggle" class="inline-flex items-center justify-center w-10 h-10 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 transition-all focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500" aria-label="Toggle theme">
            <span id="icon-moon" class="hidden dark:inline">🌙</span>
            <span id="icon-sun" class="inline dark:hidden">☀️</span>
        </button>
        <a class="inline-flex items-center gap-1.5 px-4 py-2 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-sm font-medium text-slate-700 dark:text-slate-200 hover:bg-indigo-50 dark:hover:bg-slate-700 hover:border-blue-400 dark:hover:border-blue-500 hover:shadow-sm transition-all no-underline focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500" href="http://localhost:8081" target="_blank" rel="noopener">
            <span class="text-lg leading-none">🗄️</span> phpMyAdmin
        </a>
    </div>
</header>

<section class="mb-8 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-xl p-5">
    <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
        <div class="bg-gray-50 dark:bg-slate-800 rounded-lg p-3">
            <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wide mb-1">PHP Version</p>
            <p class="text-lg font-semibold text-slate-800 dark:text-white"><?= htmlspecialchars($phpVersion, ENT_QUOTES, 'UTF-8') ?></p>
        </div>
        <div class="bg-gray-50 dark:bg-slate-800 rounded-lg p-3">
            <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wide mb-1">Server</p>
            <p class="text-sm font-semibold text-slate-800 dark:text-white truncate" title="<?= htmlspecialchars($serverSoftware, ENT_QUOTES, 'UTF-8') ?>"><?= htmlspecialchars($serverSoftware, ENT_QUOTES, 'UTF-8') ?></p>
        </div>
        <div class="bg-gray-50 dark:bg-slate-800 rounded-lg p-3">
            <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wide mb-1">Upload Max</p>
            <p class="text-lg font-semibold text-slate-800 dark:text-white"><?= htmlspecialchars($uploadMax, ENT_QUOTES, 'UTF-8') ?></p>
        </div>
        <div class="bg-gray-50 dark:bg-slate-800 rounded-lg p-3">
            <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wide mb-1">Opcache</p>
            <p class="text-lg font-semibold <?= $opcacheEnabled ? 'text-emerald-600 dark:text-emerald-400' : 'text-slate-400' ?>"><?= $opcacheEnabled ? 'Enabled' : 'Disabled' ?></p>
        </div>
    </div>
    <hr class="my-4 border-slate-100 dark:border-slate-800">
    <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
        <?php foreach ($services as $name => $port): ?>
        <div class="bg-gray-50 dark:bg-slate-800 rounded-lg p-3">
            <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wide mb-1"><?= htmlspecialchars($name, ENT_QUOTES, 'UTF-8') ?></p>
            <?php if ($name === 'MariaDB'): ?>
                <p class="text-sm font-semibold text-slate-800 dark:text-white">localhost:<?= $port ?></p>
            <?php else: ?>
                <a class="text-sm font-semibold text-blue-600 dark:text-blue-400 hover:text-blue-700 dark:hover:text-blue-300 underline" href="http://localhost:<?= $port ?>" target="_blank" rel="noopener">localhost:<?= $port ?></a>
            <?php endif; ?>
        </div>
        <?php endforeach; ?>
    </div>
    <hr class="my-4 border-slate-100 dark:border-slate-800">
    <div>
        <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wide mb-2">Extensions</p>
        <div class="flex flex-wrap gap-1.5">
            <?php foreach ($extensionStatus as $ext => $loaded): ?>
            <span class="<?= $loaded ? 'bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-300' : 'bg-slate-100 dark:bg-slate-800 text-slate-400 dark:text-slate-500' ?> px-2 py-0.5 rounded-full text-xs font-medium"><?= htmlspecialchars($ext, ENT_QUOTES, 'UTF-8') ?></span>
            <?php endforeach; ?>
        </div>
    </div>
</section>

<?php if ($error): ?>
<main class="grid grid-cols-[repeat(auto-fill,minmax(280px,1fr))] gap-6">
    <div class="col-span-full text-center py-16 px-8 text-red-500 dark:text-red-400">
        <p><?= htmlspecialchars($error, ENT_QUOTES, 'UTF-8') ?></p>
    </div>
</main>

<?php elseif (empty($projects)): ?>
<main class="grid grid-cols-[repeat(auto-fill,minmax(280px,1fr))] gap-6">
    <div class="col-span-full text-center py-16 px-8 text-slate-400 dark:text-slate-500">
        <p>No projects found. Add a project to <code>src/</code> to get started.</p>
    </div>
</main>

<?php else: ?>
<main class="grid grid-cols-[repeat(auto-fill,minmax(280px,1fr))] gap-6">
    <?php foreach ($projects as $proj):
        [$name, $logoFile, $mtime] = $proj;
        $safeName   = htmlspecialchars($name, ENT_QUOTES, 'UTF-8');
        $humanName  = htmlspecialchars(humanize($name), ENT_QUOTES, 'UTF-8');
        $firstChar  = htmlspecialchars(mb_strtoupper($name[0]), ENT_QUOTES, 'UTF-8');
        $dateStr    = htmlspecialchars(date('Y-m-d', $mtime), ENT_QUOTES, 'UTF-8');
    ?>
    <article class="group bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl shadow-sm dark:shadow-slate-950/50 hover:-translate-y-1 hover:shadow-lg dark:hover:shadow-slate-950/80 transition-all duration-200 overflow-hidden flex flex-col">
            <div class="flex items-center gap-4 p-5">
                <div class="w-14 h-14 rounded-2xl bg-gradient-to-br from-blue-500 to-indigo-600 shadow-lg shadow-blue-500/25 flex items-center justify-center flex-shrink-0">
                    <span class="text-white text-2xl font-bold leading-none"><?= $firstChar ?></span>
                </div>
                <div class="min-w-0 flex-1">
                    <h2 class="text-lg font-semibold text-slate-800 dark:text-white truncate"><?= $humanName ?></h2>
                    <p class="text-xs text-slate-400 dark:text-slate-500 mt-0.5">🕐 <?= $dateStr ?></p>
                </div>
            </div>
            <div class="flex-1"></div>
            <a class="flex items-center justify-center gap-2 px-4 py-3 bg-slate-50 dark:bg-slate-800/60 text-sm font-semibold text-blue-600 dark:text-blue-400 hover:bg-blue-500 hover:text-white dark:hover:bg-blue-600 dark:hover:text-white transition-all no-underline border-t border-slate-100 dark:border-slate-800" href="/<?= $safeName ?>/">
                Abrir proyecto <span class="transition-transform group-hover:translate-x-1" aria-hidden="true">&rarr;</span>
            </a>
        </article>
    <?php endforeach; ?>
</main>
<?php endif; ?>

<script>
(function(){var t=localStorage.getItem('theme');if(t==='light'){document.documentElement.classList.remove('dark')}else{document.documentElement.classList.add('dark')}})();
document.getElementById('theme-toggle').addEventListener('click',function(){var h=document.documentElement;h.classList.toggle('dark');localStorage.setItem('theme',h.classList.contains('dark')?'dark':'light')});
</script>
</body>
</html>