# GH Actions Toolkit

A curated collection of production-ready GitHub Actions workflows for CI/CD, releases, Docker, security, and repository maintenance.

## Workflows

| Workflow | File | Trigger | Description |
|----------|------|---------|-------------|
| **CI** | `ci.yml` | Push / PR to main, develop | Lint, test (Node 18/20/22 matrix), and build with artifact upload |
| **Release** | `release.yml` | Version tags / Manual | Semantic versioning, changelog generation, GitHub Release creation |
| **Deploy** | `deploy.yml` | Manual / After release | Deploy to VPS via SSH with backup and PM2 restart |
| **Docker** | `docker.yml` | Push to main / Tags / PR | Multi-platform Docker build, push to GHCR, SBOM generation |
| **PR Check** | `pr-check.yml` | Pull request events | Auto-label by file paths, size labels (XS-XL), large PR warnings |
| **Security** | `security.yml` | Push to main / Weekly | npm audit, CodeQL analysis, license compliance check |
| **Stale** | `stale.yml` | Daily schedule | Auto-close stale issues (30d) and PRs (14d) with configurable exemptions |

## Scripts

| Script | Description |
|--------|-------------|
| `scripts/version-bump.sh` | Bump version (patch/minor/major), update package.json, create git tag |
| `scripts/deploy.sh` | Deploy to VPS via SCP + SSH with backup rotation |

## Setup

### Required Secrets

Configure these in your repository Settings > Secrets and variables > Actions:

| Secret | Used By | Description |
|--------|---------|-------------|
| `VPS_HOST` | Deploy | Server hostname or IP address |
| `VPS_USER` | Deploy | SSH username on the server |
| `VPS_SSH_KEY` | Deploy | SSH private key for authentication |

### Required Variables

| Variable | Used By | Description |
|----------|---------|-------------|
| `DEPLOY_HOST` | Deploy | Public hostname for environment URL |
| `APP_DIR` | Deploy | Remote application directory path |
| `PM2_APP_NAME` | Deploy | PM2 process name |

### Environment Protection

For production deployments, enable environment protection rules:

1. Go to Settings > Environments > production
2. Add required reviewers
3. Enable "Wait timer" if desired
4. Restrict deployment branches to `main`

## Usage

```bash
# Bump version and create tag
npm run version:patch   # 1.0.0 -> 1.0.1
npm run version:minor   # 1.0.0 -> 1.1.0
npm run version:major   # 1.0.0 -> 2.0.0

# Push tag to trigger release + deploy
git push origin main --follow-tags

# Manual deploy via CLI
VPS_HOST=your-server VPS_USER=deploy APP_DIR=/var/www/app PM2_APP_NAME=my-app \
  bash scripts/deploy.sh production
```

## License

MIT

---

## 🇫🇷 Documentation en français

### Description
gh-actions-toolkit est une collection de workflows GitHub Actions réutilisables pour CI/CD, releases automatiques, déploiement Docker et analyses de sécurité. Il inclut également un script de bump de version sémantique avec intégration Git (commit + tag automatiques).

### Installation
Copiez les fichiers `.yml` du répertoire `.github/workflows/` dans votre dépôt. Configurez les secrets GitHub requis (`VPS_HOST`, `VPS_USER`, `VPS_KEY`, `PM2_APP_NAME`).

### Utilisation
```bash
# Bumper la version et créer un tag
npm run version:patch   # 1.0.0 -> 1.0.1
npm run version:minor   # 1.0.0 -> 1.1.0
npm run version:major   # 1.0.0 -> 2.0.0

# Pousser le tag pour déclencher le déploiement
git push origin main --follow-tags
```

### Lancer les tests
```bash
npm test
```

Consultez la documentation en anglais ci-dessus pour la liste complète des workflows et la configuration des environnements protégés.
