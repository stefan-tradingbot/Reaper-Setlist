import { svelteTesting } from '@testing-library/svelte/vite';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import Icons from 'unplugin-icons/vite';
import { readFileSync } from 'fs';
import { join } from 'path';

// Custom icon loader for Iconify JSON collections
function loadIconifyCollection(collectionName: string) {
	const collectionPath = join(
		process.cwd(),
		'node_modules',
		`@iconify-json/${collectionName}`,
		'icons.json'
	);
	const collection = JSON.parse(readFileSync(collectionPath, 'utf-8'));

	return (iconName: string) => {
		const iconData = collection.icons[iconName];
		if (!iconData) return undefined;

		const width = iconData.width || collection.width || 24;
		const height = iconData.height || collection.height || 24;
		const body = iconData.body;

		return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" fill="currentColor">${body}</svg>`;
	};
}

export default defineConfig({
	server: {
		proxy: {
			'/_/': {
				target: 'http://127.0.0.1:8080',
				changeOrigin: true
			}
		}
	},

	plugins: [
		sveltekit(),
		Icons({
			compiler: 'svelte',
			scale: 1.2,
			defaultClass: 'icon',
			customCollections: {
				mdi: loadIconifyCollection('mdi'),
				'line-md': loadIconifyCollection('line-md')
			}
		})
	],

	test: {
		workspace: [
			{
				extends: './vite.config.ts',
				plugins: [svelteTesting()],

				test: {
					name: 'client',
					environment: 'jsdom',
					clearMocks: true,
					include: ['src/**/*.svelte.{test,spec}.{js,ts}'],
					exclude: ['src/lib/server/**'],
					setupFiles: ['./vitest-setup-client.ts']
				}
			},
			{
				extends: './vite.config.ts',

				test: {
					name: 'server',
					environment: 'node',
					include: ['src/**/*.{test,spec}.{js,ts}'],
					exclude: ['src/**/*.svelte.{test,spec}.{js,ts}']
				}
			}
		]
	}
});
