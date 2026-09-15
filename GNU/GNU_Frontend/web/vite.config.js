import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import { bunny } from 'laravel-vite-plugin/fonts';
import tailwindcss from '@tailwindcss/vite';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const frontendRoot = dirname(fileURLToPath(import.meta.url));
const backendRoot = resolve(frontendRoot, '../../GNU_Backend');

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.js'],
            refresh: true,
            publicDirectory: '../../GNU_Backend/public',
            buildDirectory: 'build',
            hotFile: resolve(backendRoot, 'public/hot'),
            base: frontendRoot,
            fonts: [
                bunny('Fraunces', { weights: [500] }),
                bunny('IBM Plex Sans', { weights: [400, 500, 600] }),
                bunny('IBM Plex Mono', { weights: [400, 500] }),
            ],
        }),
        tailwindcss(),
    ],
    build: {
        outDir: resolve(backendRoot, 'public/build'),
        emptyOutDir: true,
    },
    server: {
        watch: {
            ignored: ['**/storage/framework/views/**'],
        },
    },
});
