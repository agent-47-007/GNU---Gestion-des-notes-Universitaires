<!DOCTYPE html>
<html lang="fr">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="theme-color" content="#1B2942">
        <title>Inscription étudiant — GNU</title>
        @vite(['resources/css/app.css', 'resources/js/app.js'])
    </head>
    <body class="auth-page">
        <header class="auth-header">
            <a class="brand" href="{{ route('home') }}" aria-label="GNU, accueil">
                <svg class="gnu-emblem" viewBox="0 0 48 48" aria-hidden="true"><rect x="4" y="8" width="40" height="4" rx="1"/><rect x="7" y="15" width="34" height="4" rx="1" opacity=".85"/><rect x="11" y="22" width="26" height="4" rx="1" opacity=".7"/><rect x="16" y="29" width="16" height="4" rx="1" opacity=".55"/><rect class="gnu-emblem-accent" x="21" y="36" width="6" height="4" rx="1"/></svg>
                <span><strong>GNU</strong><small>Gestion des notes · Système LMD</small></span>
            </a>
            <a class="showcase-back" href="{{ route('login') }}">← Se connecter</a>
        </header>
        <main class="auth-content">
            <div class="auth-main" id="registration">
                <section class="auth-form-side" aria-labelledby="register-title">
                    <div class="auth-title-row"><span class="auth-logo-box"><svg class="gnu-emblem" viewBox="0 0 48 48" aria-hidden="true"><rect x="4" y="8" width="40" height="4" rx="1"/><rect x="7" y="15" width="34" height="4" rx="1" opacity=".85"/><rect x="11" y="22" width="26" height="4" rx="1" opacity=".7"/><rect x="16" y="29" width="16" height="4" rx="1" opacity=".55"/><rect class="gnu-emblem-accent" x="21" y="36" width="6" height="4" rx="1"/></svg></span><div><p class="eyebrow auth-kicker">Portail étudiant</p><h1 id="register-title">Créer votre compte GNU</h1><p class="auth-intro">L’inscription publique crée un compte étudiant actif.</p></div></div>
                    <form id="register-form" novalidate>
                        <div class="field"><label for="register-nom">Nom</label><input id="register-nom" name="nom" type="text" autocomplete="family-name" required></div>
                        <div class="field"><label for="register-prenom">Prénom</label><input id="register-prenom" name="prenom" type="text" autocomplete="given-name" required></div>
                        <div class="field"><label for="register-matricule">Matricule</label><input id="register-matricule" name="matricule" type="text" autocomplete="username" placeholder="Ex. 21T2355" required><small>Ce matricule deviendra votre identifiant de connexion.</small></div>
                        <div class="field"><label for="register-password">Mot de passe</label><input id="register-password" name="password" type="password" autocomplete="new-password" required></div>
                        <div class="field"><label for="register-password-confirmation">Confirmer le mot de passe</label><input id="register-password-confirmation" name="password_confirmation" type="password" autocomplete="new-password" required></div>
                        <p class="auth-feedback" id="register-feedback" role="alert" hidden></p>
                        <button class="auth-submit" type="submit">Créer mon compte étudiant</button>
                    </form>
                    <div class="auth-help"><span>Vous avez déjà un compte ?</span><a href="{{ route('login') }}">Se connecter</a></div>
                </section>
                <aside class="auth-aside"><div><p class="aside-kicker">INSCRIPTION SÉCURISÉE</p><h2>Un accès étudiant personnel.</h2><p>Votre compte vous permettra de consulter votre profil, vos résultats et vos démarches pédagogiques.</p><div class="auth-points"><div class="auth-point"><b>1</b><span><strong>Profil étudiant</strong>Votre matricule est associé à un profil étudiant unique.</span></div><div class="auth-point"><b>2</b><span><strong>Accès protégé</strong>Votre mot de passe est chiffré avant son stockage.</span></div><div class="auth-point"><b>3</b><span><strong>Rôle contrôlé</strong>Les comptes enseignant et agent sont créés par l’administration.</span></div></div></div><div class="auth-meta"><span>Année Académique 2024-2025</span><span>Licence · Master · Doctorat</span></div></aside>
            </div>
        </main>
    </body>
</html>