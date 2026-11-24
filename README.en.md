# S.A.G.E.

[Polski](README.md) | **English**

A dashboard for weather, tree health, and soil moisture analysis using Sentinel-1 and ERA5-Land. Google Earth Engine trains the model and exports GeoTIFF files to Google Drive. The backend downloads the resulting rasters, and the UI displays them on a map. MongoDB stores orchard boundaries, trees, and observations associated with raster pixels.

## Quick start

You need Git, Python 3.12+, a running Docker installation with Docker Compose, and a Google account with access to the Earth Engine project and Google Drive exports. On Windows, use **Git Bash**. The default GEE project is `hackathon-515400`; select your own project through `EARTHENGINE_PROJECT` or `earthengine.json`.

```bash
git clone --branch main https://github.com/KungFuPepus/field-under-pressure-materials.git
cd field-under-pressure-materials
bash setup.sh
```

The script prepares a local Python environment and GEE configuration, verifies authentication, builds the images, and starts MongoDB, the backend, and the UI. If a browser opens, sign in with an account that has access to the project and grant access to Google Drive. To switch accounts, run `bash setup.sh --relogin`.

Open the [dashboard](http://127.0.0.1:5173) or [Swagger API documentation](http://127.0.0.1:8000/docs). Start a new analysis through **Analytics → Load field data**. In the Polish interface, choose **Analityka → Pobierz dane pola**.

The script selects the latest archive in `db/backups/`. A new archive revision uses a separate MongoDB volume. Running setup again with the same archive reuses its existing volume, and previous volumes retain their data.

To update an existing checkout, start Docker and run these commands from the repository root:

```bash
git pull --ff-only
bash setup.sh
```

## Manual Docker Compose setup

Use this alternative to prepare the configuration manually. Use `setup.sh` above when you want MongoDB volume selection to follow the database archive revision automatically.

From the repository root, copy the configuration file and set your `project_id` in `earthengine.json`. Git ignores this local file.

```powershell
Copy-Item earthengine.example.json earthengine.json
python -m pip install earthengine-api
earthengine authenticate
docker compose -f docker-compose.yml -f docker-compose.gee.yml up -d --build
```

Open the [UI](http://127.0.0.1:5173) or [Swagger API documentation](http://127.0.0.1:8000/docs). Select an orchard in **Analytics** and click **Load field data** to start the exports and save the results automatically. The Earth Engine account must have access to Google Drive.

Running `docker compose up -d --build` starts the dashboard and restores the bundled MongoDB archive when its volume is first initialized. Reading stored data and viewing saved GeoTIFF files locally do not require Earth Engine authentication. The automated `setup.sh` workflow verifies Earth Engine access before starting the services.

### Configuration overrides

- `EARTHENGINE_PROJECT`: overrides `project_id` from the JSON file. The CLI `--project` argument has the highest priority.
- `EARTHENGINE_CREDENTIALS_FILE`: path to the authentication file on the host. The default is `~/.config/earthengine/credentials`.
- `EARTHENGINE_MODEL_ASSET`: identifier of the saved radar model used by the forecast API.
- `MONGO_ORCHARD_ID`: limits CLI commands and legacy soil moisture jobs to one orchard.
- `MONGO_URI`: MongoDB connection URI for scripts and the backend running directly on the host.
- `BACKEND_MONGO_URI`: optional MongoDB connection URI for the backend running in Docker. By default, it connects to the `mongodb` service.
- `UI_PORT`, `BACKEND_PORT`, `MONGO_PORT`: ports exposed on the host.

## Code and data

- [`ui/`](ui/README.md): React dashboard with local and automatic GeoTIFF viewing.
- [`backend/`](backend/README.md): FastAPI endpoints, GEE exports, and soil moisture forecasts.
- [`ML/soil_moisture/`](ML/soil_moisture/README.md): machine learning scripts, orchard imports, and tree analysis.
- [`db/`](db/SETUP.md): MongoDB setup, imports into `Orchard`, and the tree data structure.
- [Hackathon materials](docs/HACKATHON.md): organizer instructions, data sources, and the starter notebook.

The linked component documentation is currently in Polish.

## Run MongoDB, the API, and the dashboard locally

For this alternative, install Python 3.12+, Node.js with npm or pnpm, MongoDB Server, and MongoDB Database Tools. From the repository root, run:

```powershell
python -m pip install -r backend/requirements.txt
python db/scripts/start_weather.py --with-ui
```

Add `--mongo-bin` and `--tools-bin` if MongoDB Server and Database Tools are not on your PATH. This launcher uses the `field_under_pressure_20261121_230119.archive.gz` archive by default; use `--archive` to select a different archive. It restores the database, starts weather updates, and launches the API and Vite.

See [ML integration](docs/ML_INTEGRATION.md) for Earth Engine configuration and assessment details.

## Local development

Install the dependencies in a Python 3.12 environment. When running through Docker, the images provide Python and Node.js.

```powershell
python -m pip install -r requirements.txt
python -m pip install pre-commit
python -m pre_commit install
```

Pre-commit checks Python with Ruff and validates commit messages against Conventional Commits. Installing the additional ML notebook dependencies is optional. See the [dependency list](ML/requirements-notebook.txt):

```powershell
python -m pip install -r ML/requirements-notebook.txt
```
