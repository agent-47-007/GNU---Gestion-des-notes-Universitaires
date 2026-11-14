# GNU · Campus numérique

Client Flutter connecté à l’API Laravel. Le même code couvre les espaces étudiant, enseignant et agent sur Web, Android et iOS. Les fonctions d’administration système sont disponibles aux comptes agent autorisés par le backend.

## Démarrage Web

```bash
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8780 --dart-define=GNU_API_BASE_URL=http://127.0.0.1:8000/api/v1
```

## Démarrage Android

Installez Android Studio avec le SDK Android, puis acceptez ses licences :

```bash
flutter doctor
flutter doctor --android-licenses
```

Démarrez l’API dans un terminal à la racine de `backend` :

```bash
php artisan serve --host=0.0.0.0 --port=8000
```

Puis, depuis `frontend`, lancez un émulateur Android :

```bash
flutter pub get
flutter devices
flutter run --dart-define=GNU_API_BASE_URL=http://10.0.2.2:8000/api/v1
```

`10.0.2.2` permet à l’émulateur Android d’atteindre le serveur de développement de l’ordinateur. Sur un téléphone réel, GNU affiche l’adresse du serveur sur l’écran de connexion : remplacez `10.0.2.2` par l’adresse IP locale de l’ordinateur, par exemple `http://192.168.1.20:8000/api/v1`. Le téléphone et l’ordinateur doivent être sur le même réseau, l’API doit écouter sur `0.0.0.0` et le pare-feu doit autoriser le port 8000. Le trafic HTTP local est activé uniquement pour les builds Android de débogage.

Pour installer une build de débogage :

```bash
flutter build apk --debug
```

L’APK est créé dans `build/app/outputs/flutter-apk/`. Pour une distribution, utilisez l’URL HTTPS de production et une clé de signature Android propre à l’établissement.

Pour préparer une signature de production, créez et conservez un keystore privé, copiez `android/key.properties.example` vers `android/key.properties`, puis renseignez le chemin du keystore, son alias et ses mots de passe. Le fichier `key.properties` est ignoré par Git. Construisez ensuite le paquet de distribution :

```bash
flutter build appbundle --release --dart-define=GNU_API_BASE_URL=https://api-etablissement.example/api/v1
```

## Démarrage iOS

Ouvrez `ios/Runner.xcworkspace` dans Xcode sur macOS, choisissez une équipe de signature, puis lancez l’application sur un simulateur ou un iPhone. Pour le serveur de développement, fournissez son nom local `.local` ou une URL HTTPS avec `GNU_API_BASE_URL`. Les versions de production doivent toujours utiliser HTTPS.

## Build Web de production

```bash
GNU_API_BASE_URL=https://api-etablissement.example/api/v1 bash tool/build_production.sh
```

Une session Web locale ouverte sur une adresse IP privée en HTTP utilise un stockage navigateur de test, car WebCrypto n’est pas disponible dans ce contexte. Ce mode est réservé aux comptes de test.
