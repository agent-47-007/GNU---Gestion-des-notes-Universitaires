<!DOCTYPE html>
<html lang="fr">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="theme-color" content="#1B2942">
        <title>Connexion — GNU</title>
        @vite(['resources/css/app.css', 'resources/js/app.js'])
    </head>
    <body class="auth-page">
        <header class="auth-header">
            <a class="brand" href="{{ route('home') }}" aria-label="GNU, accueil">
                <svg class="gnu-emblem" viewBox="0 0 48 48" aria-hidden="true"><rect x="4" y="8" width="40" height="4" rx="1"/><rect x="7" y="15" width="34" height="4" rx="1" opacity=".85"/><rect x="11" y="22" width="26" height="4" rx="1" opacity=".7"/><rect x="16" y="29" width="16" height="4" rx="1" opacity=".55"/><rect class="gnu-emblem-accent" x="21" y="36" width="6" height="4" rx="1"/></svg>
                <span><strong>GNU</strong><small>Gestion des notes · Système LMD</small></span>
            </a>
            <nav class="auth-nav" aria-label="Navigation secondaire"><a class="auth-nav-active" href="#authentification"><svg class="nav-svg" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3 4 6v5c0 5 3.4 8.2 8 10 4.6-1.8 8-5 8-10V6l-8-3Z"/><path d="m9 12 2 2 4-4"/></svg>Authentification</a><a href="{{ route('guide.lmd') }}">Guide & Normes LMD</a><a href="{{ route('support.registres') }}">Support & Registres</a><span class="auth-user"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="8" r="3"/><path d="M5 20a7 7 0 0 1 14 0"/></svg></span></nav>
        </header>

        <main class="auth-content">
        <div class="auth-main" id="authentification">
            <section class="auth-form-side" aria-labelledby="login-title">
                <div class="auth-title-row"><span class="auth-logo-box"><svg class="gnu-emblem" viewBox="0 0 48 48" aria-hidden="true"><rect x="4" y="8" width="40" height="4" rx="1"/><rect x="7" y="15" width="34" height="4" rx="1" opacity=".85"/><rect x="11" y="22" width="26" height="4" rx="1" opacity=".7"/><rect x="16" y="29" width="16" height="4" rx="1" opacity=".55"/><rect class="gnu-emblem-accent" x="21" y="36" width="6" height="4" rx="1"/></svg></span><div><p class="eyebrow auth-kicker">Portail universitaire</p><h1 id="login-title">Connexion au Système GNU</h1><p class="auth-intro">Gestion des Notes & Délibérations · Licence, Master, Doctorat</p></div></div>

                <form id="login-form" novalidate>
                    <label class="role-label">Vous vous connectez en tant que :</label>
                    <div class="role-selector" role="group" aria-label="Type de compte">
                        <button class="role-button is-selected" type="button" data-login="ENS-4182-INFO"><strong><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 10h16M6 10v8m6-8v8m6-8v8M3 20h18M12 4l9 4H3l9-4Z"/></svg></strong>Enseignant</button>
                        <button class="role-button" type="button" data-login="ADM-8842-CELLULE"><strong><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 21h16M6 21V8h12v13M9 8V5h6v3M9 12h2m2 0h2m-6 4h2m2 0h2"/></svg></strong>Scolarité / Jury</button>
                        <button class="role-button" type="button" data-login="21T2355"><strong><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="7" r="3"/><path d="M5 20a7 7 0 0 1 14 0"/></svg></strong>Étudiant</button>
                    </div>

                    <div class="field"><label for="login">Identifiant ou matricule</label><input id="login" name="login" type="text" autocomplete="username" value="ENS-4182-INFO" placeholder="Ex. 21A123" required></div>
                    <div class="field"><div class="password-row"><label for="password">Mot de passe</label><a href="#forgot">Mot de passe oublié ?</a></div><div class="password-input"><input id="password" name="password" type="password" autocomplete="current-password" placeholder="Votre mot de passe" required><button type="button" data-password-toggle aria-label="Afficher ou masquer le mot de passe">◉</button></div></div>
                    <label class="remember"><input type="checkbox" checked> <span>Rester connecté sur cet appareil</span></label>
                    <p class="auth-feedback" id="login-feedback" role="alert" hidden></p>
                    <button class="auth-submit" type="submit">↪ &nbsp; SE CONNECTER</button>
                </form>
                <div class="auth-help"><span>Vous êtes étudiant sans compte ?</span><a href="{{ route('register') }}">Créer un compte</a></div>
            </section>

            <aside class="auth-aside">
                <div>
                    <p class="aside-kicker">SYSTÈME LMD UNIVERSITAIRE</p>
                    <h2>GNU — Gestion des Notes & Évaluations</h2>
                    <p>Plateforme académique unifiée pour la gestion complète du cycle universitaire en Licence, Master et Doctorat.</p>
                    <div class="auth-points"><div class="auth-point"><b>⇥</b><span><strong>1. Saisie des Notes</strong>Contrôle continu, devoirs surveillés et sessions d’examen finaux par matière et unité d’enseignement.</span></div><div class="auth-point"><b>▤</b><span><strong>2. Calculs & Crédits ECTS</strong>Calcul automatique des moyennes semestrielles, règles de compensation LMD et attribution des crédits.</span></div><div class="auth-point"><b>▧</b><span><strong>3. Délibérations & Relevés</strong>Génération immédiate des procès-verbaux de jury et relevés de notes officiels pour les étudiants.</span></div></div>
                </div>
                <div class="auth-meta"><span>Année Académique 2024-2025</span><span>Licence · Master · Doctorat</span></div>
            </aside>
        </main>
        <section class="auth-features" aria-label="Fonctionnalités GNU"><article><b>☑</b><div><h3>Saisie Sécurisée</h3><p>Saisie fluide et guidée des notes d'examen et de contrôle continu par les enseignants autorisés.</p></div></article><article><b>⚖</b><div><h3>Délibérations LMD</h3><p>Application rigoureuse des règles de compensation entre unités d'enseignement et semestres.</p></div></article><article><b>✥</b><div><h3>Relevés Officiels</h3><p>Édition instantanée des procès-verbaux de session et impression des relevés de notes homologués.</p></div></article></section>
        </div>
        <footer class="auth-footer"><div class="footer-brand"><svg class="gnu-emblem" viewBox="0 0 48 48" aria-hidden="true"><rect x="4" y="8" width="40" height="4" rx="1"/><rect x="7" y="15" width="34" height="4" rx="1" opacity=".85"/><rect x="11" y="22" width="26" height="4" rx="1" opacity=".7"/><rect x="16" y="29" width="16" height="4" rx="1" opacity=".55"/><rect class="gnu-emblem-accent" x="21" y="36" width="6" height="4" rx="1"/></svg><span><strong>GNU — Gestion des Notes Universitaires</strong><small>Système académique pour les formations LMD (Licence, Master, Doctorat)</small></span></div><div><span>Année Universitaire 2024-2025</span><a href="#support">Assistance & Support</a></div></footer>
        </main>
    </body>
</html>
