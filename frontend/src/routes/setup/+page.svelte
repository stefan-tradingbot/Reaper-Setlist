<script lang="ts">
	import { configuration, notifications } from '$lib';
	import { getApi } from '$lib/api/api';
	import Button from '$lib/components/Button/Button.svelte';
	import ConfigurationInfo from '$lib/components/ConfigurationInfo/ConfigurationInfo.svelte';
	import Form from '$lib/components/Form/Form.svelte';
	import InstructionBox from '$lib/components/InstructionBox/InstructionBox.svelte';
	import type { StepStatus } from '$lib/components/Step/Step.svelte';
	import Step from '$lib/components/Step/Step.svelte';
	import type { Backup } from '$lib/models/backup';
	import { generateUUID } from '$lib/util';
	import ExportIcon from 'virtual:icons/mdi/export';
	import ImportIcon from 'virtual:icons/mdi/import';
	import RefreshIcon from 'virtual:icons/mdi/refresh';
	import RecordIcon from 'virtual:icons/mdi/record-circle-outline'; // Updated icon
	import FolderIcon from 'virtual:icons/mdi/folder-open';
	import CheckAllIcon from 'virtual:icons/mdi/checkbox-multiple-marked';
	import CheckNoneIcon from 'virtual:icons/mdi/checkbox-multiple-blank-outline';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	const api = getApi();

	let folderPath = $state<string | undefined>(data.folderPath);
	// Initialize status based on existing script action ID
	let scriptInstallationStatus = $state<StepStatus>(data.scriptActionId && data.scriptActionId.trim() !== '' ? 'completed' : 'pending');
	let isRefreshing = $state<boolean>(false);
	let hasCheckedInitially = $state<boolean>(false);

	// Folder validation state
	let folderValidationStatus = $state<'pending' | 'checking' | 'success' | 'warning' | 'error'>('pending');
	let folderValidationMessage = $state<string>('');
	let lastValidatedPath = $state<string | undefined>(data.folderPath);

	const nextSteps = [
		{ label: 'Add your songs', href: '/song' },
		{ label: 'Create setlists', href: '/' }
	];

	const setupSteps = [
		{ label: 'Open Reaper and go to "Actions" > "Show Action List".' },
		{ label: 'If you installed this via ReaPack, the reaper-setlist.lua script should already be listed here.' },
		{ label: 'If not, click "New Action" > "Load ReaScript..." and open the reaper-setlist.lua script.' },
		{ label: 'Simply run the script to register it.' },
		{ label: 'Use the refresh button below to check installation status.' },
		{ label: 'Enter the root folder path where your backing tracks are stored in the form below.' },
		{ label: 'Click "Save" to store these settings.' }
	];

	// Only check script installation status once on initial load if not already completed
	$effect(() => {
		if (!hasCheckedInitially && scriptInstallationStatus !== 'completed') {
			hasCheckedInitially = true;
			checkScriptInstallation();
		}
	});

	// Reset validation status when folder path changes (user is typing)
	$effect(() => {
		if (folderPath !== lastValidatedPath && folderValidationStatus !== 'pending') {
			folderValidationStatus = 'pending';
			folderValidationMessage = '';
		}
	});

	async function handleSubmit(event: Event) {
		event.preventDefault();
		const formData = new FormData(event.target as HTMLFormElement);
		const folderPathValue: string = formData.get('backing-tracks-folder')?.toString() || '';
		let escapedFolderPath = folderPathValue.replaceAll('\\', '/'); // Normalize path for consistency
		while (escapedFolderPath.includes('//')) {
			escapedFolderPath = escapedFolderPath.replace('//', '/'); // Remove any double slashes
		}

		// Start validation
		folderValidationStatus = 'checking';
		folderValidationMessage = 'Validating folder...';
		// Update local state to reflect the saved values
		folderPath = escapedFolderPath;
		lastValidatedPath = escapedFolderPath;

		try {
			const result = await api.script.testProjectsFolder(escapedFolderPath);
			if (!result.valid) {
				folderValidationStatus = 'error';
				folderValidationMessage = result.message || 'Invalid folder path. Please check the path and try again.';
				return;
			}
			// Update folder path in the store
			await configuration.updateFolderPath(escapedFolderPath);

			folderValidationStatus = 'success';
			folderValidationMessage = result.message || 'Folder path is valid!';
			notifications.success('Settings saved successfully!');
		} catch (error) {
			folderValidationStatus = 'error';
			folderValidationMessage = `Error: ${(error as Error).message}`;
			notifications.error(`Failed to save settings: ${(error as Error).message}`);
			return;
		}
	}

	async function checkScriptInstallation() {
		if (isRefreshing) return;

		isRefreshing = true;
		scriptInstallationStatus = 'running';

		try {
			// Try to get the script action ID from the backend
			const actionId = await api.scriptSettings.getScriptActionId();

			if (actionId && actionId.trim() !== '') {
				configuration.reset();
				await configuration.initialize(fetch);
				const nonce = generateUUID();
				const result = await api.script.testActionId(nonce);
				if (result === `Test action ID received: ${actionId}`) {
					// If the action ID is valid, update the status to completed
					scriptInstallationStatus = 'completed';
				} else {
					// If the action ID is not valid, set status to error
					scriptInstallationStatus = 'error';
				}
				scriptInstallationStatus = 'completed';
			} else {
				scriptInstallationStatus = 'error';
			}
		} catch (error) {
			console.error('Error checking script installation:', error);
			scriptInstallationStatus = 'error';
		} finally {
			isRefreshing = false;
		}
	}

	async function exportData() {
		const allSongs = await api.songs.list();
		const allSetlists = await api.sets.list();
		const dataToExport: Backup = {
			songs: allSongs,
			sets: allSetlists
		};
		const jsonData = JSON.stringify(dataToExport, null, 2);
		const blob = new Blob([jsonData], { type: 'application/json' });
		const url = URL.createObjectURL(blob);
		const link = document.createElement('a');
		link.href = url;
		link.download = 'reaper-setlist-data.json';
		document.body.appendChild(link);
		link.click();
		document.body.removeChild(link);
		URL.revokeObjectURL(url);
		notifications.success('Data exported successfully!');
	}

	async function importData() {
		const fileInput = document.createElement('input');
		fileInput.type = 'file';
		fileInput.accept = '.json';
		fileInput.onchange = async (event: Event) => {
			const target = event.target as HTMLInputElement;
			if (target.files && target.files.length > 0) {
				const file = target.files[0];
				try {
					const text = await file.text();
					const importedData = JSON.parse(text) as Backup;

					// Step 1: Import songs and create ID mapping
					const oldToNewSongIdMap = new Map<string, string>();

					for (const song of Object.values(importedData.songs)) {
						const { id, ...songWithoutId } = song;
						const newSong = await api.songs.add(songWithoutId);
						oldToNewSongIdMap.set(id, newSong.id);
					}

					// Step 2: Import setlists with updated song IDs
					for (const setlist of Object.values(importedData.sets)) {
						const { ...setlistWithoutId } = setlist;
						const updatedSetlist = {
							...setlistWithoutId,
							songs: setlist.songs.map((oldSongId) => oldToNewSongIdMap.get(oldSongId) || oldSongId)
						};
						await api.sets.add(updatedSetlist);
					}

					notifications.success('Data imported successfully!');
				} catch (error) {
					notifications.error(`Failed to import data: ${(error as Error).message}`);
				}
			}
		};
		fileInput.click();
	}

	// Export state
	let showExportForm = $state(false);
	let isLoadingTracks = $state(false);
	let availableTracks = $state<string[]>([]);
	let selectedTracks = $state<Set<string>>(new Set());
	let exportPath = $state<string>('');

	// Load exportPath from configuration when available
	$effect(() => {
		if (!exportPath && configuration.exportPath) {
			exportPath = configuration.exportPath;
		}
	});

	async function openExportForm() {
		showExportForm = true;
		isLoadingTracks = true;
		try {
			availableTracks = await api.script.getTrackNames();
			selectedTracks = new Set(availableTracks);
			// Use saved exportPath, or fallback to folderPath
			if (!exportPath) {
				exportPath = configuration.exportPath || folderPath || '';
			}
		} catch (error) {
			notifications.error(`Failed to fetch tracks: ${(error as Error).message}`);
			showExportForm = false;
		} finally {
			isLoadingTracks = false;
		}
	}

	function toggleTrack(track: string) {
		const newSelection = new Set(selectedTracks);
		if (newSelection.has(track)) {
			newSelection.delete(track);
		} else {
			newSelection.add(track);
		}
		selectedTracks = newSelection;
	}

	function selectAllTracks() {
		selectedTracks = new Set(availableTracks);
	}

	function deselectAllTracks() {
		selectedTracks = new Set();
	}

	async function browseForFolder() {
		try {
			const result = await api.script.browseFolder(exportPath || folderPath || '/');
			if (result && result.trim() !== '') {
				exportPath = result;
				// Save to configuration for persistence
				await configuration.updateExportPath(exportPath);
			}
		} catch (error) {
			notifications.error(`Failed to open folder browser: ${(error as Error).message}`);
		}
	}

	async function startExport() {
		if (selectedTracks.size === 0) {
			notifications.error('Please select at least one track.');
			return;
		}
		if (!exportPath) {
			notifications.error('Please enter an export path.');
			return;
		}

		try {
			// Save the export path for future use
			await configuration.updateExportPath(exportPath);
			
			await api.script.exportRecordings(Array.from(selectedTracks), exportPath);
			notifications.success('Recording export started! Check Reaper for progress.');
			showExportForm = false;
		} catch (error) {
			notifications.error(`Failed to start export: ${(error as Error).message}`);
		}
	}
</script>

<div class="content">
	<h1>Setup</h1>

	{#if scriptInstallationStatus === 'error'}
		<InstructionBox title="Script Installation" steps={setupSteps} variant="help" listType="ordered" />
	{:else}
		<InstructionBox title="Next steps:" steps={nextSteps} variant="success" listType="unordered" />
	{/if}

	<div class="script-status">
		<Step
			title="Script Installation Status"
			description={scriptInstallationStatus === 'completed'
				? 'Script is installed and ready to use'
				: scriptInstallationStatus === 'running'
					? 'Checking installation status...'
					: 'Script not detected. Please install the script in Reaper and refresh.'}
			status={scriptInstallationStatus}
		/>
		<Button elementType="button" onclick={checkScriptInstallation} disabled={isRefreshing} variant="text">
			<RefreshIcon />
			Refresh Status
		</Button>
	</div>

	<Form onsubmit={handleSubmit}>
		<div class="form-group">
			<label for="backing-tracks-folder">Backing Tracks Root Folder:</label>
			<input
				bind:value={folderPath}
				type="text"
				id="backing-tracks-folder"
				name="backing-tracks-folder"
				placeholder="e.g., /path/to/your/backing/tracks"
				class={folderValidationStatus === 'success'
					? 'success'
					: folderValidationStatus === 'warning'
						? 'warning'
						: folderValidationStatus === 'error'
							? 'error'
							: ''}
			/>
			{#if folderValidationMessage}
				<div class="validation-message validation-message--{folderValidationStatus}">
					{folderValidationMessage}
				</div>
			{:else if folderPath && folderPath.trim() !== '' && folderPath !== lastValidatedPath}
				<div class="validation-message validation-message--pending">Click "Save" to validate this folder path</div>
			{/if}
		</div>

		<div class="submit-section">
			<Button elementType="submit" color="success">Save</Button>
		</div>
	</Form>

	<div class="import-export">
		<h3>Data Management</h3>
		<div class="import-export-buttons">
			<Button elementType="button" onclick={exportData} variant="text">
				<ExportIcon />
				Export Data
			</Button>
			<Button elementType="button" onclick={importData} variant="text">
				<ImportIcon />
				Import Data
			</Button>
		</div>
	</div>

	<div class="import-export">
		<h3>Recording Export</h3>
		
		{#if showExportForm}
			<div class="export-form">
				<div class="form-group">
					<label for="export-path">Export Path:</label>
					<div class="path-input-group">
						<input 
							type="text" 
							id="export-path" 
							bind:value={exportPath} 
							placeholder="e.g., /path/to/export/folder"
						/>
						<Button variant="secondary" onclick={browseForFolder} title="Browse Folder">
							<FolderIcon />
						</Button>
					</div>
				</div>

				<div class="form-group">
					<div class="track-list-header">
						<label>Select Tracks to Export:</label>
						<div class="track-actions">
							<Button elementType="button" variant="text" onclick={selectAllTracks} title="Select All">
								<CheckAllIcon /> Select All
							</Button>
							<Button elementType="button" variant="text" onclick={deselectAllTracks} title="Deselect All">
								<CheckNoneIcon /> None
							</Button>
						</div>
					</div>
					
					{#if isLoadingTracks}
						<div class="loading-tracks">Loading tracks from Reaper...</div>
					{:else if availableTracks.length === 0}
						<div class="no-tracks">No tracks found in open projects.</div>
					{:else}
						<div class="track-list">
							{#each availableTracks as track}
								<label class="track-checkbox">
									<input 
										type="checkbox" 
										checked={selectedTracks.has(track)} 
										onchange={() => toggleTrack(track)}
									/>
									<span class="track-name">{track}</span>
								</label>
							{/each}
						</div>
					{/if}
				</div>

				<div class="export-actions">
					<Button elementType="button" onclick={startExport} disabled={selectedTracks.size === 0 || !exportPath}>
						<RecordIcon />
						Start Export
					</Button>
					<Button elementType="button" variant="text" onclick={() => showExportForm = false}>
						Cancel
					</Button>
				</div>
			</div>
		{:else}
			<div class="import-export-buttons">
				<Button elementType="button" onclick={openExportForm} variant="text">
					<RecordIcon />
					Configure Export
				</Button>
			</div>
		{/if}
	</div>
</div>

<style>
	.content {
		margin: 0 auto;
		padding: 2rem;
		width: 100%;
		box-sizing: border-box;
	}

	@media (max-width: 768px) {
		.content {
			padding: 1rem;
		}
	}

	.script-status {
		display: flex;
		flex-direction: column;
		gap: 1rem;
		margin: 1rem 0;
	}

	.script-status :global(.step) {
		margin: 0;
	}

	.import-export {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		margin-top: 2rem;
	}

	.import-export-buttons {
		display: flex;
		gap: 1rem;
	}

	@media (max-width: 768px) {
		.import-export-buttons {
			flex-direction: column;
			gap: 0.5rem;
		}
	}

	.validation-message {
		font-size: 0.875rem;
		margin-top: 0.5rem;
		padding: 0.25rem 0;
	}

	.validation-message--success {
		color: var(--green);
	}

	.validation-message--warning {
		color: var(--yellow);
	}

	.validation-message--error {
		color: var(--red);
	}

	.validation-message--checking {
		color: var(--comment);
	}

	.validation-message--pending {
		color: var(--comment);
		font-style: italic;
	}

	.export-form {
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
		background: var(--surface-1);
		padding: 1.5rem;
		border-radius: 0.5rem;
		border: 1px solid var(--border);
		margin-top: 1rem;
	}

	.path-input-group {
		display: flex;
		gap: 0.5rem;
	}

	.path-input-group input {
		flex: 1;
	}

	.track-list-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.5rem;
	}
	
	.track-list-header label {
		margin-bottom: 0;
	}

	.track-actions {
		display: flex;
		gap: 0.5rem;
	}

	.track-list {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
		gap: 0.5rem;
		max-height: 300px;
		overflow-y: auto;
		border: 1px solid var(--border);
		padding: 1rem;
		border-radius: 0.25rem;
		background: var(--surface-2);
	}

	.track-checkbox {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		cursor: pointer;
		padding: 0.5rem;
		border-radius: 0.25rem;
		transition: background-color 0.2s;
		user-select: none;
	}

	.track-checkbox:hover {
		background: var(--surface-3);
	}
	
	.track-checkbox input[type="checkbox"] {
		width: 1.2em;
		height: 1.2em;
		margin: 0;
		cursor: pointer;
	}
	
	.track-name {
		flex: 1;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.export-actions {
		display: flex;
		gap: 1rem;
		margin-top: 0.5rem;
		padding-top: 1rem;
		border-top: 1px solid var(--border);
	}
	
	.loading-tracks, .no-tracks {
		padding: 2rem;
		text-align: center;
		color: var(--text-muted);
		background: var(--surface-2);
		border-radius: 0.25rem;
		border: 1px solid var(--border);
	}
</style>
