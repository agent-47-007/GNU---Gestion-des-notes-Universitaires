<!DOCTYPE html>
<html lang="fr">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="theme-color" content="#1B2942">
        <title>GNU — Gestion des notes</title>
        @vite(['resources/css/app.css', 'resources/js/app.js'])
    </head>
    <body>
        <a class="skip-link" href="#contenu">Aller au contenu</a>

        <div class="app-shell">
            <aside class="sidebar" id="navigation-principale" aria-label="Navigation principale">
                <div class="brand-lockup">
                    <a class="brand" href="{{ url('/') }}" aria-label="GNU, accueil">
                        <svg class="gnu-emblem" viewBox="0 0 48 48" aria-hidden="true"><rect x="4" y="8" width="40" height="4" rx="1"/><rect x="7" y="15" width="34" height="4" rx="1" opacity=".85"/><rect x="11" y="22" width="26" height="4" rx="1" opacity=".7"/><rect x="16" y="29" width="16" height="4" rx="1" opacity=".55"/><rect class="gnu-emblem-accent" x="21" y="36" width="6" height="4" rx="1"/></svg>
                        <span><strong>GNU</strong><small>Gestion des notes · Système LMD</small></span>
                    </a>
                    <button class="icon-button sidebar-close" type="button" data-menu-close aria-label="Fermer la navigation">×</button>
                </div>

                <div class="sidebar-section">
                    <p class="eyebrow">Espace de travail</p>
                    <nav class="main-nav">
                        <a class="nav-link is-active" href="#accueil"><span class="nav-icon">⌂</span>Vue d’ensemble</a>
                        <a class="nav-link" href="#releves"><span class="nav-icon">▤</span>Relevés de notes</a>
                        <a class="nav-link" href="#inscriptions"><span class="nav-icon">＋</span>Inscriptions pédagogiques</a>
                        <a class="nav-link" href="#requetes"><span class="nav-icon">◫</span>Requêtes étudiantes</a>
                    </nav>
                </div>

                <div class="sidebar-section sidebar-section-last">
                    <p class="eyebrow">Administration</p>
                    <nav class="main-nav">
                        <a class="nav-link" href="#ues"><span class="nav-icon">□</span>Catalogue des UE</a>
                        <a class="nav-link" href="#resultats"><span class="nav-icon">✓</span>Résultats & délibérations</a>
                    </nav>
                </div>

                <div class="sidebar-footer">
                    <div class="user-chip">
                        <span class="avatar" data-user-initials>GN</span>
                        <span><strong data-user-name>Utilisateur GNU</strong><small data-user-role>Session locale</small></span>
                        <button class="icon-button" type="button" data-logout aria-label="Se déconnecter">↪</button>
                    </div>
                    <p class="mono muted">GNU / 2026.1</p>
                </div>
            </aside>

            <div class="page-area">
                <header class="topbar">
                    <button class="menu-toggle" type="button" data-menu-open aria-controls="navigation-principale" aria-expanded="false"><span></span><span></span><span></span><b>Menu</b></button>
                    <div class="topbar-context"><span class="status-dot"></span>Session active</div>
                    <a class="profile-trigger" href="{{ route('profile') }}" aria-label="Ouvrir le profil"><span class="avatar avatar-small" data-user-initials>GN</span><span class="profile-name" data-user-name>Utilisateur GNU</span><span aria-hidden="true">⌄</span></a>
                </header>

                <main id="contenu" class="content">
                    <div class="breadcrumb" aria-label="Fil d’Ariane"><span>Université de Douala</span><b>›</b><span>Faculté des Sciences</span><b>›</b><strong>Informatique</strong></div>
                    <section class="page-heading" id="accueil">
                        <div><p class="eyebrow accent">Jeudi 10 septembre 2026</p><h1>Bonjour, <span data-user-first-name>Utilisateur</span>.</h1><p class="lede">Retrouvez ici vos résultats, vos inscriptions et les dernières informations de votre parcours.</p></div>
                        <a class="button button-primary" href="#releves"><span aria-hidden="true">＋</span> Consulter mon relevé</a>
                    </section>

                    <section class="status-strip" aria-label="Résumé académique">
                        <div><span class="eyebrow">Identifiant</span><strong class="mono" data-user-code>—</strong></div>
                        <div><span class="eyebrow">Rôle</span><strong data-user-role>—</strong></div>
                        <div><span class="eyebrow">Profil</span><strong class="mono" data-user-profile>—</strong></div>
                        <div><span class="eyebrow">Statut</span><strong class="status status-validated"><span></span><span data-user-status>Vérification...</span></strong></div>
                    </section>

                    <div class="dashboard-grid">
                        <section class="panel panel-wide" id="releves">
                            <div class="panel-heading"><div><p class="eyebrow">Dernière publication</p><h2>Relevé de notes · Semestre 1</h2></div><span class="status status-validated"><span></span>Validé</span></div>
                            <div class="table-wrap"><table><thead><tr><th>Matière</th><th>Crédits</th><th>Note</th><th>Statut</th></tr></thead><tbody><tr><td>Mathématiques discrètes</td><td class="mono">06</td><td class="grade">15.4<span>/20</span></td><td><span class="status status-validated"><span></span>Validé</span></td></tr><tr><td>Systèmes d’exploitation</td><td class="mono">05</td><td class="grade">13.5<span>/20</span></td><td><span class="status status-pending"><span></span>En attente</span></td></tr><tr><td>Réseaux informatiques</td><td class="mono">05</td><td class="grade grade-missing">—</td><td><span class="status status-missing"><span></span>Manquant</span></td></tr></tbody></table></div>
                            <a class="text-link" href="#bulletin">Voir le relevé complet <span aria-hidden="true">→</span></a>
                        </section>

                        <section class="panel" id="inscriptions"><div class="panel-heading"><div><p class="eyebrow">Parcours</p><h2>Progression LMD</h2></div><span class="mono panel-value">126 / 180</span></div><div class="progress-line"><span style="width: 70%"></span></div><p class="panel-note"><strong>126 crédits validés</strong><br>Il vous reste 54 crédits pour terminer la licence.</p><a class="text-link" href="#parcours">Voir mon parcours <span aria-hidden="true">→</span></a></section>
                        <section class="panel panel-wide" id="requetes"><div class="panel-heading"><div><p class="eyebrow">À suivre</p><h2>Actualités de votre dossier</h2></div><a class="text-link" href="#toutes">Tout voir <span aria-hidden="true">→</span></a></div><div class="activity-list"><article><span class="activity-mark activity-mark-red">!</span><div><strong>Une note est encore attendue</strong><p>Réseaux informatiques · Semestre 1</p></div><time class="mono">Il y a 2 j</time></article><article><span class="activity-mark activity-mark-green">✓</span><div><strong>Inscription pédagogique confirmée</strong><p>Semestre 2 · 30 crédits sélectionnés</p></div><time class="mono">12 août</time></article></div></section>
                    </div>
                </main>
                <footer class="page-footer"><span>GNU · Gestion des notes d'une Université</span><span class="mono">Système LMD / 2026</span></footer>
            </div>
        </div>
        <div class="scrim" data-menu-close></div>
    </body>
</html>
