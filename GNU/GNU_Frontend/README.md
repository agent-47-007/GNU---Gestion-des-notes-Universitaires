# GNU Frontend

Espace de regroupement des clients GNU :

- `web/` : frontend web GNU, actuellement servi par Laravel/Vite depuis `../GNU_Backend/resources`.
- `app/` : future application mobile GNU.
- `shared/` : contrats, identité visuelle et conventions communes.

## Développement web

Les sources frontend web sont dans `web/`. Laravel reste dans `../GNU_Backend` et sert les vues, l'API et les assets compilés.

```bash
cd web
npm run dev
```

Dans un second terminal :

```bash
cd ../GNU_Backend
php artisan serve --host=127.0.0.1 --port=8000
```

Pages actuelles : `/connexion`, `/guide-lmd` et `/support-registres`.

## Application

Le dossier `app/` réserve l'espace du client mobile. La technologie mobile sera choisie avant son initialisation afin de partager proprement les contrats API et l'identité GNU.
