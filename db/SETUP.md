# MongoDB — Field Under Pressure (Hackathon GEO · Crop Science)

Reprodukowalny obraz Docker z bazą danych MongoDB odtwarzaną automatycznie z najnowszego dumpa (`.archive.gz`) — wraz ze wszystkimi kolekcjami, dokumentami, indeksami i walidatorami `$jsonSchema` (`_id: ObjectId`).

## Kolekcje w bazie `field_under_pressure`

- `User`
- `Orchard`
- `Tree`
- `CropPref`
- `Geofence`
- `JobSchedule`
- `JobLog`
- `ManualControl`

## Uruchomienie i inicjalizacja

Przy pierwszym uruchomieniu (pusty wolumen `mongodb_data`) skrypt `/docker-entrypoint-initdb.d/01-restore-latest.sh` automatycznie odtworzy bazę z najnowszego archiwum z katalogu `db/backups/`.

### macOS / Linux (bash)

```bash
docker compose up -d --build
```

### Windows (PowerShell)

```powershell
# Uruchomienie i weryfikacja gotowości bazy
.\db\scripts\init.ps1

# Reset bazy do stanu z najnowszego dumpa (usuwa wolumen i startuje od zera)
.\db\scripts\init.ps1 -Reset
```

> **Windows ExecutionPolicy:** Jeśli PowerShell blokuje uruchamianie skryptów `.ps1`, uruchom jednorazowo:
> `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
> lub wywołuj skrypty przez `powershell -ExecutionPolicy Bypass -File .\db\scripts\init.ps1`.

Domyślne dane połączenia (można nadpisać zmiennymi środowiskowymi lub plikiem `.env`):

| Zmienna | Wartość domyślna |
|---|---|
| `MONGO_PORT` | `27017` |
| `MONGO_ROOT_USER` | `admin` |
| `MONGO_ROOT_PASSWORD` | `admin123` |
| `MONGO_DB` | `field_under_pressure` |

Przykładowy connection string:

```text
mongodb://admin:admin123@localhost:27017/field_under_pressure?authSource=admin
```

## Uruchomienie samego obrazu Docker (bez Docker Compose)

```bash
docker build -t field-under-pressure-mongodb ./db
docker run -d --name fup-mongodb -p 27017:27017 field-under-pressure-mongodb
```

## Udostępnianie bazy między deweloperami (Backup & Restore)

Cała baza `field_under_pressure` (wszystkie kolekcje, dokumenty, indeksy i walidatory) jest eksportowana do archiwum z timestampem: `db/backups/field_under_pressure_YYYYMMDD_HHMMSS.archive.gz`.

### 1. Eksport bazy do archiwum (`backup`)

**macOS / Linux (bash):**
```bash
# Zrzut całej bazy do db/backups/field_under_pressure_YYYYMMDD_HHMMSS.archive.gz
./db/scripts/backup.sh

# Opcjonalnie: zapis do własnej ścieżki
./db/scripts/backup.sh path/to/custom.archive.gz
```

**Windows (PowerShell):**
```powershell
# Zrzut całej bazy do db\backups\field_under_pressure_YYYYMMDD_HHMMSS.archive.gz
.\db\scripts\backup.ps1

# Opcjonalnie: zapis do własnej ścieżki
.\db\scripts\backup.ps1 .\custom.archive.gz
```

Wygenerowane archiwum można scommitować do repozytorium lub przekazać bezpośrednio innemu deweloperowi.

### 2. Odtworzenie bazy z archiwum (`restore`)

Bez podania ścieżki skrypt automatycznie wybiera **najnowsze** archiwum `field_under_pressure_*.archive.gz` z `db/backups/` i czyści lokalną bazę przed importem (1:1 z archiwum).

**macOS / Linux (bash):**
```bash
# Odtworzenie najnowszego archiwum 1:1
./db/scripts/restore.sh

# Wskazane archiwum lub bez czyszczenia lokalnej bazy (--no-drop)
./db/scripts/restore.sh db/backups/field_under_pressure_20261120_235405.archive.gz
./db/scripts/restore.sh --no-drop
```

**Windows (PowerShell):**
```powershell
# Odtworzenie najnowszego archiwum 1:1
.\db\scripts\restore.ps1

# Wskazane archiwum lub bez czyszczenia lokalnej bazy (-NoDrop)
.\db\scripts\restore.ps1 .\db\backups\field_under_pressure_20261120_235405.archive.gz
.\db\scripts\restore.ps1 -NoDrop
```

### Zewnętrzna instancja MongoDB (`MONGO_URI`)

Oba skrypty działają także z dowolnym `MONGO_URI` (wymagają wtedy lokalnego `mongodump`/`mongorestore`):

```bash
# macOS / Linux
MONGO_URI="mongodb://admin:admin123@localhost:27017/?authSource=admin" ./db/scripts/backup.sh
MONGO_URI="mongodb://admin:admin123@localhost:27017/?authSource=admin" ./db/scripts/restore.sh
```

```powershell
# Windows (PowerShell)
$env:MONGO_URI="mongodb://admin:admin123@localhost:27017/?authSource=admin"; .\db\scripts\backup.ps1
$env:MONGO_URI="mongodb://admin:admin123@localhost:27017/?authSource=admin"; .\db\scripts\restore.ps1
```

## Weryfikacja kolekcji

```bash
docker compose exec mongodb mongosh \
  -u admin -p admin123 --authenticationDatabase admin field_under_pressure \
  --eval "db.getCollectionNames().forEach(c => print(c, '-> docs:', db.getCollection(c).countDocuments()))"
```

## Reset bazy do stanu z najnowszego dumpa

```bash
# macOS / Linux
docker compose down -v && docker compose up -d --build
```

```powershell
# Windows (PowerShell)
.\db\scripts\init.ps1 -Reset
```
