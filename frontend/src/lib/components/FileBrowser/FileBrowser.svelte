<script lang="ts">
	import { getApi } from '$lib/api/api';
	import Button from '$lib/components/Button/Button.svelte';
	import Dialog from '$lib/components/Dialog/Dialog.svelte';
	import FolderIcon from 'virtual:icons/mdi/folder';
	import FileIcon from 'virtual:icons/mdi/file';
	import ArrowUpIcon from 'virtual:icons/mdi/arrow-up';
	import CheckIcon from 'virtual:icons/mdi/check';
	import CloseIcon from 'virtual:icons/mdi/close';

	interface Props {
		initialPath?: string;
		onSelect: (path: string) => void;
		onCancel: () => void;
	}

	let { initialPath = '/', onSelect, onCancel }: Props = $props();

	const api = getApi();
	let currentPath = $state(initialPath);
	let subdirs = $state<string[]>([]);
	let files = $state<string[]>([]);
	let isLoading = $state(false);
	let error = $state<string | null>(null);

	// Load directory contents when path changes
	$effect(() => {
		loadDirectory(currentPath);
	});

	async function loadDirectory(path: string) {
		isLoading = true;
		error = null;
		try {
			const result = await api.script.listDirectory(path);
			// Ensure path ends with separator for display/logic if needed, or just trust backend
			currentPath = result.path;
			subdirs = result.subdirs;
			files = result.files;
		} catch (e) {
			error = (e as Error).message;
		} finally {
			isLoading = false;
		}
	}

	function navigateUp() {
		// Simple parent directory logic
		// Remove last segment
		// Handle Windows/Unix separators
		const separator = currentPath.includes('\\') ? '\\' : '/';
		const parts = currentPath.split(separator).filter(p => p);
		if (parts.length > 0) {
			parts.pop();
			const newPath = parts.length === 0 ? separator : parts.join(separator);
			// If on windows, might need to handle drive letter differently, but let's assume simple case for now
			// Or just let backend handle ".." ? No, backend takes absolute path.
			// Let's try to rely on backend normalization if possible, but we need to send a string.
			// If path is "/" (mac root), popping makes it empty string, which backend handles as root.
			// If path is "C:\" (win root), popping makes it "C:", which might be weird.
			
			// Better: just strip last segment
			let parent = currentPath.substring(0, currentPath.lastIndexOf(separator));
			if (parent === '' && currentPath.startsWith('/')) parent = '/'; // Root on unix
            if (parent.endsWith(':')) parent = parent + separator; // Root on windows (e.g. C:\)
			
			loadDirectory(parent || separator);
		}
	}

	function navigateTo(subdir: string) {
		const separator = currentPath.endsWith('/') || currentPath.endsWith('\\') ? '' : (currentPath.includes('\\') ? '\\' : '/');
		loadDirectory(currentPath + separator + subdir);
	}

	function handleSelect() {
		onSelect(currentPath);
	}
</script>

<div class="file-browser-overlay">
	<div class="file-browser">
		<div class="header">
			<h3>Select Folder</h3>
			<Button variant="icon" onclick={onCancel}><CloseIcon /></Button>
		</div>

		<div class="current-path">
			<Button variant="icon" onclick={navigateUp} disabled={currentPath === '/' || currentPath.length <= 3 && currentPath.includes(':')} title="Go Up">
				<ArrowUpIcon />
			</Button>
			<input type="text" bind:value={currentPath} onkeydown={(e) => e.key === 'Enter' && loadDirectory(currentPath)} />
			<Button variant="icon" onclick={() => loadDirectory(currentPath)} title="Go">Go</Button>
		</div>

		<div class="file-list">
			{#if isLoading}
				<div class="loading">Loading...</div>
			{:else if error}
				<div class="error">{error}</div>
			{:else}
				{#if subdirs.length === 0 && files.length === 0}
					<div class="empty">Folder is empty</div>
				{/if}
				
				{#each subdirs as subdir}
					<button class="file-item folder" onclick={() => navigateTo(subdir)} type="button">
						<FolderIcon />
						<span>{subdir}</span>
					</button>
				{/each}
				
				{#each files as file}
					<div class="file-item file">
						<FileIcon />
						<span>{file}</span>
					</div>
				{/each}
			{/if}
		</div>

		<div class="footer">
			<div class="selected-info">
				Selected: <strong>{currentPath}</strong>
			</div>
			<div class="actions">
				<Button variant="text" onclick={onCancel}>Cancel</Button>
				<Button color="primary" onclick={handleSelect}>
					<CheckIcon />
					Select This Folder
				</Button>
			</div>
		</div>
	</div>
</div>

<style>
	.file-browser-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
		backdrop-filter: blur(2px);
	}

	.file-browser {
		background: var(--surface-1);
		border: 1px solid var(--border);
		border-radius: 0.5rem;
		width: 600px;
		max-width: 90vw;
		max-height: 80vh;
		display: flex;
		flex-direction: column;
		box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
	}

	.header {
		padding: 1rem;
		border-bottom: 1px solid var(--border);
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.header h3 {
		margin: 0;
		font-size: 1.25rem;
	}

	.current-path {
		display: flex;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		background: var(--surface-2);
		align-items: center;
	}

	.current-path input {
		flex: 1;
		padding: 0.25rem 0.5rem;
		border: 1px solid var(--border);
		border-radius: 0.25rem;
		background: var(--surface-1);
		color: var(--text);
	}

	.file-list {
		flex: 1;
		overflow-y: auto;
		padding: 0.5rem;
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		min-height: 300px;
	}

	.file-item {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0.5rem;
		border-radius: 0.25rem;
		text-align: left;
		background: transparent;
		border: none;
		color: var(--text);
		width: 100%;
	}

	.file-item.folder {
		cursor: pointer;
	}

	.file-item.folder:hover {
		background: var(--surface-3);
	}

	.file-item.file {
		color: var(--text-muted);
	}

	.footer {
		padding: 1rem;
		border-top: 1px solid var(--border);
		display: flex;
		justify-content: space-between;
		align-items: center;
		background: var(--surface-2);
		border-bottom-left-radius: 0.5rem;
		border-bottom-right-radius: 0.5rem;
	}

	.selected-info {
		font-size: 0.875rem;
		color: var(--text-muted);
		max-width: 50%;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.actions {
		display: flex;
		gap: 0.5rem;
	}
	
	.loading, .error, .empty {
		padding: 2rem;
		text-align: center;
		color: var(--text-muted);
	}
	
	.error {
		color: var(--error);
	}
</style>
