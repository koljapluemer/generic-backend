# generic-backend

A minimal FastAPI service that accepts arbitrary JSON POST requests and persists each payload to disk as a timestamped file.

## API

| Method | Path | Body | Response |
|--------|------|------|----------|
| `POST` | `/`  | Any valid JSON | `{"file": "<filename>"}` |

Files are written to the directory configured by `DATA_DIR` (default: `./data`).

## Local development

```bash
# Install uv (https://github.com/astral-sh/uv)
curl -LsSf https://astral.sh/uv/install.sh | sh

uv sync
uv run uvicorn main:app --reload
```

The API is then available at `http://localhost:8000`.

---

## VPS deployment

The setup uses:

- **systemd** to manage the process (see `generic-backend.service`)
- **nginx** as a reverse proxy (port 80/443 → 127.0.0.1:8000)
- **uv** for reproducible Python dependency installs
- App lives at `/opt/generic-backend`, runs as `www-data`

### Prerequisites

- A VPS running Debian/Ubuntu with SSH root access
- Your repo pushed to GitHub (public, or the server has SSH access to it)

### Initial deployment

SSH into the VPS and run:

```bash
# Option A — pipe directly from GitHub (replace URL with your repo)
export REPO_URL=https://github.com/YOUR_ORG/YOUR_REPO.git
curl -fsSL https://raw.githubusercontent.com/YOUR_ORG/YOUR_REPO/main/scripts/deploy.sh | sudo -E bash

# Option B — clone first, then run
git clone https://github.com/YOUR_ORG/YOUR_REPO.git /tmp/generic-backend
sudo REPO_URL=https://github.com/YOUR_ORG/YOUR_REPO.git bash /tmp/generic-backend/scripts/deploy.sh
```

The script will:

1. Install `git`, `nginx`, and `uv` if not present
2. Clone the repo to `/opt/generic-backend`
3. Create a virtualenv and install dependencies via `uv sync`
4. Install and start the `generic-backend` systemd service
5. Write an nginx reverse-proxy config and reload nginx

### Add HTTPS (recommended)

```bash
apt-get install -y certbot python3-certbot-nginx
# Edit /etc/nginx/sites-available/generic-backend and set server_name to your domain
certbot --nginx -d your.domain.com
```

certbot will also set up automatic renewal.

### Updating

After pushing changes to GitHub, SSH into the VPS and run:

```bash
sudo bash /opt/generic-backend/scripts/update.sh
```

This pulls the latest commit, syncs dependencies if `uv.lock` changed, and restarts the service. Zero manual steps.

### Useful commands

```bash
# Service status
systemctl status generic-backend

# Live logs
journalctl -u generic-backend -f

# Restart manually
sudo systemctl restart generic-backend

# Check nginx config
nginx -t
```

### File layout on the server

```
/opt/generic-backend/
├── main.py
├── pyproject.toml
├── uv.lock
├── .venv/                  # managed by uv
├── data/                   # persisted JSON payloads
└── scripts/
    ├── deploy.sh
    └── update.sh

/etc/systemd/system/generic-backend.service
/etc/nginx/sites-available/generic-backend
```
