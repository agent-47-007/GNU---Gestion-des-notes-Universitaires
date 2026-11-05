# Client GNU (Flutter)

Client Web/mobile de GNU, connecté à l’API Laravel. Voir le [README du dépôt](../README.md) pour le démarrage local, l’accès téléphone, les tests et le build.

## Commandes essentielles

```bash
flutter pub get
flutter test --no-pub
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8780 --dart-define=GNU_API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Pour une vraie build de production, `GNU_API_BASE_URL` doit être l’URL HTTPS de l’API fournie par l’environnement de déploiement :

```bash
GNU_API_BASE_URL=https://api-etablissement.example/api/v1 bash tool/build_production.sh
```

Une session Web locale ouverte sur une adresse IP privée en HTTP utilise un stockage navigateur de test, car WebCrypto n’est pas disponible dans ce contexte. Ce mode est réservé aux comptes de test.
