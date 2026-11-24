# S.A.G.E.

**Polski** | [English](README.en.md)

Panel pogody, kondycji drzew i analizy wilgotności gleby na podstawie Sentinel‑1 i ERA5‑Land. Earth Engine trenuje model i eksportuje GeoTIFF na Google Drive. Backend pobiera gotowy raster, a UI pokazuje go na mapie. MongoDB przechowuje granice pól, drzewa i obserwacje przypisane do pikseli.

## Szybki start

Wymagane są Git, Python 3.12+, działający Docker z Compose oraz konto Google z dostępem do projektu Earth Engine i eksportów na Dysku Google. Na Windowsie używaj **Git Bash**. Domyślny projekt GEE to `hackathon-515400`; własny projekt możesz wskazać przez `EARTHENGINE_PROJECT` lub `earthengine.json`.

```bash
git clone --branch main https://github.com/KungFuPepus/field-under-pressure-materials.git
cd field-under-pressure-materials
bash setup.sh
```

Skrypt przygotowuje lokalne środowisko Python i konfigurację GEE, sprawdza logowanie, buduje obrazy oraz uruchamia MongoDB, backend i UI. Jeśli otworzy się przeglądarka, zaloguj się kontem z dostępem do projektu i udziel dostępu do Dysku Google. Zmianę konta umożliwia `bash setup.sh --relogin`.

Otwórz [panel](http://127.0.0.1:5173) lub [Swagger API](http://127.0.0.1:8000/docs). Nową analizę uruchomisz przez **Analytics → Load field data**; w polskiej wersji interfejsu: **Analityka → Pobierz dane pola**.

Skrypt wybiera najnowsze archiwum z `db/backups/`. Nowa wersja archiwum otrzymuje osobny wolumen MongoDB. Ponowne uruchomienie z tym samym archiwum korzysta z istniejącego wolumenu, a wcześniejsze wolumeny zachowują dane.

Aby zaktualizować istniejącą kopię, uruchom Docker i wykonaj z katalogu repozytorium:

```bash
git pull --ff-only
bash setup.sh
```

## Uruchomienie z Docker Compose

Wariant ręczny poniżej służy do samodzielnego przygotowania konfiguracji. Aby automatycznie wybierać wolumen na podstawie wersji zrzutu bazy, używaj `setup.sh` opisanego wyżej.

Z głównego katalogu repozytorium skopiuj konfigurację i wpisz swój `project_id` do `earthengine.json`. Plik lokalny jest ignorowany przez Git.

```powershell
Copy-Item earthengine.example.json earthengine.json
python -m pip install earthengine-api
earthengine authenticate
docker compose -f docker-compose.yml -f docker-compose.gee.yml up -d --build
```

Otwórz [UI](http://127.0.0.1:5173) lub [Swagger API](http://127.0.0.1:8000/docs). W **Analityce** wybierz pole i kliknij **Pobierz dane pola**, aby rozpocząć eksporty i automatyczny zapis wyników. Konto Earth Engine musi mieć dostęp do Google Drive. Polecenie `docker compose up -d --build` uruchamia panel i odtwarza rzeczywisty zrzut MongoDB przy pierwszej inicjalizacji wolumenu. Odczyt zapisanych danych i lokalny podgląd GeoTIFF działają bez logowania do Earth Engine.

Nadpisania konfiguracji

| Ustawienie | Zastosowanie |
| --- | --- |
| `EARTHENGINE_PROJECT` | Nadpisuje `project_id` z pliku JSON. Argument `--project` w CLI ma najwyższy priorytet. |
| `EARTHENGINE_CREDENTIALS_FILE` | Ścieżka do pliku logowania na hoście. Domyślnie `~/.config/earthengine/credentials`. |
| `EARTHENGINE_MODEL_ASSET` | Identyfikator zapisanego modelu radarowego używanego w prognozie API. |
| `MONGO_ORCHARD_ID` | Ogranicza polecenia CLI i starsze zadania wilgotności do wybranego pola. |
| `MONGO_URI` | Adres MongoDB dla skryptów i backendu uruchamianych bezpośrednio na hoście. |
| `BACKEND_MONGO_URI` | Opcjonalny adres MongoDB dla backendu w Dockerze. Domyślnie backend łączy się z usługą `mongodb`. |
| `UI_PORT`, `BACKEND_PORT`, `MONGO_PORT` | Porty udostępnione na hoście. |

## Kod i dane

| Katalog | Zawartość |
| --- | --- |
| [`ui/`](ui/README.md) | Panel React oraz lokalny i automatyczny podgląd GeoTIFF |
| [`backend/`](backend/README.md) | API FastAPI, eksporty GEE i prognoza wilgotności |
| [`ML/soil_moisture/`](ML/soil_moisture/README.md) | Skrypty ML, import pól i analiza drzew |
| [`db/`](db/SETUP.md) | MongoDB, import do `Orchard` i struktura danych drzew |
| [Materiały hackathonu](docs/HACKATHON.md) | Instrukcje organizatora, źródła danych i notebook startowy |

## Start lokalny MongoDB, API i panelu

Z głównego katalogu, z Pythonem 3.12+ oraz Node.js i npm lub pnpm, uruchom:

```powershell
python -m pip install -r backend/requirements.txt
python db/scripts/start_weather.py --with-ui
```

Dodaj `--mongo-bin` i `--tools-bin`, jeśli MongoDB Server i Database Tools są poza PATH. Skrypt używa zrzutu `230119`, rozpoczyna aktualizacje pogody, uruchamia API oraz Vite. Dokumentacja opisuje konfigurację Earth Engine i ocen. [Integracja analityki](docs/ML_INTEGRATION.md)

## Praca lokalna

Zainstaluj zależności w środowisku Python 3.12. W Dockerze Python i Node są dostarczane przez obrazy.

```powershell
python -m pip install -r requirements.txt
python -m pip install pre-commit
python -m pre_commit install
```

Pre-commit sprawdza Python przez Ruff i nazwy commitów według Conventional Commits. Instalacja dodatkowych pakietów do notebooków ML jest opcjonalna. [Lista zależności](ML/requirements-notebook.txt).

```powershell
python -m pip install -r ML/requirements-notebook.txt
```
