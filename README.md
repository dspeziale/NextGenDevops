# NextGenDevops

Container Python che ogni 10 secondi scarica il meteo corrente di alcune città italiane da
[Open-Meteo](https://open-meteo.com) (API pubblica, senza chiave) e lo salva in PostgreSQL.
Il deploy avviene con **Coolify**, il versioning è basato su **tag git semantici** (`vX.Y.Z`):
Coolify clona il repository **al tag** della versione scelta e builda l'immagine da lì.
GitHub Actions in parallelo verifica la build e pubblica l'immagine su GHCR e la GitHub Release.

```
release.ps1 1.2.0 ──► tag v1.2.0 su GitHub ──► deploy.ps1 1.2.0 ──► Coolify clona v1.2.0, builda e avvia
```

**Ambiente attuale**

| | |
|---|---|
| Repository | https://github.com/dspeziale/NextGenDevops (pubblico) |
| Coolify | http://10.20.23.64:8000 (le API rispondono sulla porta **8000**) |
| Progetto Coolify | `NextGenDevops`, environment `production` |
| UUID applicazione | `0ldidmberbwan7h0d89lrviy` |

> I comandi sono per **PowerShell su Windows** (con Docker Desktop e Git for Windows installati).
> Se PowerShell blocca gli script, una tantum: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.
> Su Linux/macOS usa gli equivalenti `scripts/*.sh`.

## Struttura

| File | Ruolo |
|---|---|
| `app/main.py` | collector: scarica il meteo e scrive in `weather_readings` (ogni riga riporta `app_version`) |
| `Dockerfile` | immagine Python; la versione arriva come build-arg `APP_VERSION` |
| `docker-compose.yml` | stack usato da Coolify: `collector` + `db` (Postgres 16 con volume persistente) |
| `docker-compose.local.yml` | override per provare in locale buildando dal sorgente |
| `.github/workflows/release.yml` | build e push dell'immagine su GHCR, crea la GitHub Release |
| `scripts/release.ps1` | crea e pusha un nuovo tag di versione |
| `scripts/deploy.ps1` | deploy/rollback di una versione via API Coolify |
| `VERSION` | ultima versione rilasciata |

## 0. Prova in locale

```powershell
Copy-Item .env.example .env      # poi apri .env e imposta almeno POSTGRES_PASSWORD
docker compose -f docker-compose.yml -f docker-compose.local.yml up --build
# in un altro terminale
docker compose exec db psql -U app -d nextgen -c "select city, temperature_c, app_version, collected_at from weather_readings order by id desc limit 10;"
# per fermare e cancellare i dati di prova
docker compose -f docker-compose.yml -f docker-compose.local.yml down -v
```

---

## 1. Primo rilascio su GitHub

1. Crea il repository su https://github.com/new: nome `NextGenDevops`, **senza** README/.gitignore
   (il codice c'è già). Poi dalla cartella del progetto:
   ```powershell
   git remote add origin https://github.com/<owner>/NextGenDevops.git
   git push -u origin main
   ```
   Al primo push Git for Windows apre il login di GitHub nel browser.
   In alternativa con la GitHub CLI: `winget install GitHub.cli`, `gh auth login`,
   `gh repo create NextGenDevops --public --source . --push`.
2. Crea il primo tag di versione:
   ```powershell
   .\scripts\release.ps1 1.0.0
   ```
3. Su GitHub > **Actions** controlla che il workflow *Build & Release* sia verde
   (conferma che il tag builda correttamente prima di deployarlo).

## 2. Configurare Coolify (passo passo)

> Questa configurazione è **già stata fatta** sull'ambiente attuale. I passi servono per capire
> cosa c'è e per rifarla su un altro server.

1. Apri Coolify (`http://10.20.23.64:8000`) > **Projects** > **+ Add** > nome `NextGenDevops`.
2. Dentro il progetto, environment `production` > **+ New Resource**.
3. Scegli **Public Repository** (o *Private Repository (with GitHub App)* se il repo è privato).
4. URL repository: `https://github.com/dspeziale/NextGenDevops`, branch: il **tag** da deployare, es. `v1.0.1`.
5. **Build Pack**: seleziona **Docker Compose**, file `/docker-compose.yml`. Conferma.
6. Scheda **Environment Variables**: Coolify le crea leggendo il compose; imposta i valori:
   | Chiave | Valore |
   |---|---|
   | `APP_VERSION` | uguale al tag senza `v`, es. `1.0.1` |
   | `POSTGRES_PASSWORD` | una password robusta |
   | `POSTGRES_USER` | `app` (opzionale) |
   | `POSTGRES_DB` | `nextgen` (opzionale) |
   | `INTERVAL_SECONDS` | `10` (secondi tra un ciclo e l'altro) |
7. Premi **Deploy**. Nella scheda **Logs** del servizio `collector` vedrai:
   `Avvio NextGenDevops collector versione 1.0.1` e le letture delle città.

Poiché Coolify segue un **tag** e non `main`, un push su `main` non cambia la produzione:
la versione in esecuzione cambia solo quando lo decidi tu con `deploy.ps1`.

> Il volume `pgdata` è persistente: aggiornamenti e rollback del collector **non** cancellano i dati.

Per usare `scripts\deploy.ps1` serve l'UUID della risorsa (sopra, oppure nell'URL della pagina in Coolify)
e un token creato in **Keys & Tokens > API tokens** (permesso *write*/*deploy*).
Lo script cambia il tag sorgente e `APP_VERSION`, avvia il deploy e attende l'esito.

## 3. Rilasciare una nuova versione

Esempio: aggiungo una città.

```powershell
# 1. modifica il codice (es. aggiungi "Bologna": (44.49, 11.34) in CITIES)
git checkout -b feat/bologna
git commit -am "feat: aggiunta Bologna"
git push -u origin feat/bologna          # apri una PR e fai merge su main
git checkout main; git pull

# 2. rilascia
.\scripts\release.ps1 1.1.0              # crea e pusha il tag v1.1.0 (GitHub Actions lo verifica)

# 3. deploy
$env:COOLIFY_URL      = "http://10.20.23.64:8000"
$env:COOLIFY_TOKEN    = "<token API Coolify>"
$env:COOLIFY_APP_UUID = "0ldidmberbwan7h0d89lrviy"
.\scripts\deploy.ps1 1.1.0
```

Oppure da interfaccia: Coolify > risorsa > **Configuration** > *Git Branch* = `v1.1.0`,
**Environment Variables** > `APP_VERSION=1.1.0`, poi **Deploy**.

### Regole di versioning (SemVer)

- `PATCH` (1.1.**1**): bugfix, nessun cambio di comportamento.
- `MINOR` (1.**2**.0): nuove funzionalità compatibili (nuove città, nuovi campi *aggiunti*).
- `MAJOR` (**2**.0.0): cambi incompatibili (es. schema DB modificato in modo non retrocompatibile).

Un tag è **immutabile** (non spostarlo mai: per una correzione crea una nuova versione), quindi
`v1.1.0` produce sempre lo stesso codice e tornare indietro significa solo deployare un tag precedente.

## 4. Rollback se qualcosa va storto

**Opzione A – cambiare versione (consigliata)**
```powershell
.\scripts\deploy.ps1 1.0.1
```
oppure in Coolify *Git Branch* = `v1.0.1` e `APP_VERSION=1.0.1` > **Deploy**. Circa un minuto.

**Opzione B – Rollback integrato di Coolify**
Risorsa > scheda **Rollback**: Coolify elenca i deploy precedenti; premi *Rollback* su quello buono.

**Opzione C – correggere il codice (roll-forward)**
```powershell
git revert <commit-difettoso>
git push
.\scripts\release.ps1 1.1.1
.\scripts\deploy.ps1 1.1.1
```

Per capire quale versione ha scritto quali dati:
```sql
SELECT app_version, count(*), min(collected_at), max(collected_at)
FROM weather_readings GROUP BY app_version ORDER BY min(collected_at);
```

**Attenzione ai cambi di schema**: il rollback del container non annulla modifiche al database.
Se una versione altera tabelle, rendi le modifiche *additive* (aggiungi colonne, non rinominarle/rimuoverle)
così la versione precedente continua a funzionare.

## Elenco versioni disponibili

```powershell
git tag --sort=-v:refname        # tag git
```
Su GitHub: **Releases** (note generate automaticamente) e **Packages > nextgendevops** (immagini).
