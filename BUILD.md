# Reaper Setlist - Build Dokumentation

Diese Anleitung beschreibt, wie das Reaper Setlist Plugin für ReaPack gebaut wird.

## Voraussetzungen

- **Node.js** (v23.6.1 oder höher)
- **npm** (kommt mit Node.js)
- **luabundler** (wird global installiert)

## Einmalige Installation

Installiere `luabundler` global:

```bash
npm install -g luabundler
```

> **Hinweis**: Es heißt `luabundler`, nicht `luabundle`!

## Build-Prozess

### 1. Lua-Bundle erstellen

Das Lua-Bundle ist das Hauptskript, das in Reaper läuft.

```bash
cd lua
rm -rf build && mkdir -p build
echo "---@diagnostic disable" > build/reaper-setlist.lua
luabundler bundle main.lua -p "?.lua" -p "?/?.lua" >> build/reaper-setlist.lua
```

**Überprüfung:**
```bash
wc -l build/reaper-setlist.lua
# Sollte ~1100+ Zeilen haben

grep -n "exportRecordings" build/reaper-setlist.lua | head -3
# Sollte die exportRecordings Funktion finden
```

### 2. Lua-Bundle nach ReaPack kopieren

```bash
cp build/reaper-setlist.lua ../reapack/repo/reaper-setlist/files/
```

### 3. Frontend bauen (Optional)

Das Frontend ist die Web-UI für das Plugin.

```bash
cd ../frontend
npm install
npm run build
```

> **Bekanntes Problem**: Der Build kann mit Icon-Fehlern fehlschlagen. Dies liegt an der `unplugin-icons` Konfiguration und den Leerzeichen im Pfadnamen.

### 4. Frontend-Dateien kopieren (Optional)

```bash
cd ..
rm -rf reapack/repo/reaper-setlist/files/reaper-setlist/*
cp -r frontend/build/* reapack/repo/reaper-setlist/files/reaper-setlist/
cp reapack/repo/reaper-setlist/files/reaper-setlist/index.html html/setlist.html
```

## Schnell-Build (nur Lua)

Wenn du nur das Lua-Bundle neu bauen möchtest:

```bash
cd lua
rm -rf build && mkdir -p build && \
echo "---@diagnostic disable" > build/reaper-setlist.lua && \
luabundler bundle main.lua -p "?.lua" -p "?/?.lua" >> build/reaper-setlist.lua && \
cp build/reaper-setlist.lua ../reapack/repo/reaper-setlist/files/
```

## Vollständiger Build mit build-for-reapack.sh

Es gibt ein Build-Script im Root-Verzeichnis:

```bash
./build-for-reapack.sh
```

> **Hinweis**: Dieses Script kann aufgrund von Pfadnamen mit Leerzeichen Probleme haben. In diesem Fall die manuellen Schritte oben verwenden.

## Troubleshooting

### Problem: "luabundler: command not found"

**Lösung**: Installiere luabundler global:
```bash
npm install -g luabundler
```

### Problem: "EPERM: operation not permitted"

**Ursache**: Der Pfad enthält Leerzeichen ("Dokumente - MacBook Pro von Michael")

**Lösung**: Verwende die manuellen Build-Schritte statt des automatischen Scripts.

### Problem: Frontend-Icons werden nicht gefunden

**Ursache**: `unplugin-icons` kann die Iconify-Collections nicht automatisch finden

**Lösung**: Die `vite.config.ts` wurde mit einem Custom Loader aktualisiert, der die Icons aus den `@iconify-json` Paketen lädt. Dies sollte bereits konfiguriert sein.

Falls das Problem erneut auftritt:
1. Prüfe, ob `@iconify-json/mdi` und `@iconify-json/line-md` installiert sind:
   ```bash
   cd frontend
   npm list @iconify-json/mdi @iconify-json/line-md
   ```

2. Falls nicht installiert:
   ```bash
   npm install @iconify-json/mdi @iconify-json/line-md --save-dev
   ```

3. Stelle sicher, dass `vite.config.ts` die `loadIconifyCollection` Funktion und `customCollections` Konfiguration enthält.

## Verzeichnisstruktur

```
Reaper-Setlist/
├── lua/
│   ├── main.lua              # Einstiegspunkt für das Lua-Bundle
│   ├── operations/           # Lua-Operationen
│   └── build/
│       └── reaper-setlist.lua  # Gebündeltes Lua-Script
├── frontend/
│   ├── src/                  # SvelteKit Frontend-Quellcode
│   └── build/                # Gebautes Frontend
├── reapack/
│   └── repo/
│       └── reaper-setlist/
│           └── files/
│               ├── reaper-setlist.lua      # Finales Lua-Bundle
│               └── reaper-setlist/         # Frontend-Dateien
└── build-for-reapack.sh      # Automatisches Build-Script
```

## Nach dem Build

1. **Git Commit**: Committe die geänderten Dateien
   ```bash
   git add reapack/repo/reaper-setlist/files/
   git commit -m "Build: Update reaper-setlist bundle"
   git push
   ```

2. **ReaPack aktualisieren**: In Reaper, gehe zu Extensions → ReaPack → Synchronize packages

## Entwicklung

### Lokales Testen ohne ReaPack

Du kannst das Lua-Script direkt in Reaper laden:

1. Öffne Reaper
2. Actions → Show action list
3. New action → Load ReaScript
4. Wähle: `lua/build/reaper-setlist.lua` oder ein anderes Script aus `lua/`

### Frontend lokal testen

```bash
cd frontend
npm run dev
```

Öffne dann http://localhost:5173/ im Browser.

> **Hinweis**: Das Frontend benötigt eine laufende Reaper-Instanz mit dem Plugin, um vollständig zu funktionieren.

## Änderungen am Code

### Lua-Code ändern

1. Bearbeite Dateien in `lua/`
2. Führe den Build-Prozess aus (siehe oben)
3. Teste das gebündelte Script in Reaper

### Frontend-Code ändern

1. Bearbeite Dateien in `frontend/src/`
2. Teste mit `npm run dev`
3. Baue mit `npm run build`
4. Kopiere nach ReaPack (siehe oben)

## Wichtige Dateien

- `lua/main.lua` - Einstiegspunkt für das Lua-Bundle
- `lua/operations_registry.lua` - Registriert alle verfügbaren Operationen
- `lua/operations/export_recordings.lua` - Export-Funktionalität
- `frontend/src/routes/+page.svelte` - Haupt-UI-Seite
- `reapack/repo/index.xml` - ReaPack-Index (manuell aktualisieren bei neuen Versionen)
