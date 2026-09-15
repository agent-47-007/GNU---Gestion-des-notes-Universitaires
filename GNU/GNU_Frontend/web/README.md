# GNU Web

Le client web GNU est séparé du backend Laravel tout en restant servi par lui pour permettre le rendu des vues Blade, la gestion des routes publiques et l'appel à l'API Laravel.

Sources : `resources/views/`, `resources/css/` et `resources/js/`

Assets compilés : `../../GNU_Backend/public/build/`

Configuration Vite : `vite.config.js`

Laravel charge les vues de ce dossier via `GNU_Backend/config/view.php`.
