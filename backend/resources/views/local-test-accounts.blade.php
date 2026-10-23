<!doctype html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>GNU · Comptes de test locaux</title>
    <style>
        body { font-family: system-ui, sans-serif; margin: 0; padding: 32px 16px; background: #f3f7f6; color: #17342f; }
        main { max-width: 760px; margin: auto; padding: 28px; background: white; border: 1px solid #dce9e5; border-radius: 16px; }
        h1 { margin-top: 0; color: #087f6a; } label { display: block; margin-top: 14px; font-weight: 600; }
        input, select { box-sizing: border-box; width: 100%; padding: 10px; margin-top: 5px; border: 1px solid #aabdb7; border-radius: 7px; font: inherit; }
        button { margin-top: 22px; padding: 11px 18px; color: white; background: #087f6a; border: 0; border-radius: 7px; font: inherit; cursor: pointer; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 8px 16px; }
        .notice { margin: 14px 0; padding: 12px; border-radius: 8px; background: #edf7f2; }
        .errors { color: #a12c2c; } [hidden] { display: none !important; }
    </style>
</head>
<body>
<main>
    <h1>Créer un compte de test</h1>
    <p>Portail local réservé à la recette. Les comptes sont créés directement dans la base configurée; aucun seeder n’est exécuté.</p>
    @if (session('status')) <div class="notice">{{ session('status') }} Login créé : <strong>{{ session('created_login') }}</strong></div> @endif
    @if ($errors->any()) <div class="notice errors"><ul>@foreach ($errors->all() as $error)<li>{{ $error }}</li>@endforeach</ul></div> @endif
    <form method="post" action="{{ route('local-test-accounts.store') }}">
        @csrf
        <div class="grid">
            <label>Rôle
                <select name="role" id="role" required>
                    <option value="ETUDIANT" @selected(old('role') === 'ETUDIANT')>Étudiant</option>
                    <option value="ENSEIGNANT" @selected(old('role') === 'ENSEIGNANT')>Enseignant</option>
                    <option value="AGENT" @selected(old('role') === 'AGENT')>Agent</option>
                </select>
            </label>
            <label>Login <input name="login" value="{{ old('login') }}" required autocomplete="username"></label>
            <label>Code utilisateur <input name="code_utilisateur" value="{{ old('code_utilisateur') }}" required></label>
            <label>Nom <input name="nom" value="{{ old('nom') }}" required></label>
            <label>Prénom <input name="prenom" value="{{ old('prenom') }}"></label>
            <label>Courriel (facultatif) <input type="email" name="courriel" value="{{ old('courriel') }}"></label>
            <label id="profile-label"><span id="profile-caption">Matricule / identifiant enseignant</span> <input name="profil_id" value="{{ old('profil_id') }}" required></label>
            <label id="class-field">Classe de rattachement
                <select name="classe_id">
                    <option value="">Choisir une classe</option>
                    @foreach ($classes as $class)<option value="{{ $class->id }}" @selected((string) old('classe_id') === (string) $class->id)>{{ $class->code_classe }}</option>@endforeach
                </select>
            </label>
            <label id="department-field" hidden>Département de rattachement
                <select name="departement_id">
                    <option value="">Choisir un département</option>
                    @foreach ($departments as $department)<option value="{{ $department->id }}" @selected((string) old('departement_id') === (string) $department->id)>{{ $department->nom_depart }}</option>@endforeach
                </select>
            </label>
            <label>Mot de passe (12 caractères minimum) <input type="password" name="password" required minlength="12" autocomplete="new-password"></label>
            <label>Confirmer le mot de passe <input type="password" name="password_confirmation" required minlength="12" autocomplete="new-password"></label>
        </div>
        <button type="submit">Créer le compte</button>
    </form>
</main>
<script>
    const role = document.getElementById('role');
    const classField = document.getElementById('class-field');
    const departmentField = document.getElementById('department-field');
    const profileLabel = document.getElementById('profile-label');
    const profileCaption = document.getElementById('profile-caption');
    const updateFields = () => {
        classField.hidden = role.value !== 'ETUDIANT';
        departmentField.hidden = role.value !== 'AGENT';
        profileCaption.textContent = role.value === 'ETUDIANT' ? 'Matricule' : (role.value === 'ENSEIGNANT' ? 'Identifiant enseignant' : 'Identifiant agent');
    };
    role.addEventListener('change', updateFields);
    updateFields();
</script>
</body>
</html>
