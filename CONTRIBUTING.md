# Contributing

Thank you for your interest in contributing to the GH Actions Toolkit! This document provides guidelines for contributing workflows and scripts.

## Adding a New Workflow

1. Create a new `.yml` file in `.github/workflows/`
2. Follow the naming convention: `<purpose>.yml` (e.g., `lint.yml`, `deploy.yml`)
3. Include a descriptive `name:` field and a comment header explaining the workflow
4. Use pinned action versions (`@v4`, not `@main`)
5. Set minimal `permissions:` for the workflow
6. Add `concurrency:` groups where appropriate to avoid duplicate runs

## Workflow Standards

### Required Elements

Every workflow must include:

- A top-level comment explaining what it does and when it triggers
- Explicit `permissions:` block (principle of least privilege)
- Pinned action versions (e.g., `actions/checkout@v4`)

### Recommended Patterns

- **Use `concurrency`** to cancel redundant runs on the same branch
- **Use `needs`** to express job dependencies clearly
- **Use matrix strategies** for multi-version testing
- **Cache dependencies** with `actions/setup-node`'s built-in caching
- **Upload artifacts** for build outputs and test reports

### Security

- Never hardcode secrets in workflow files
- Use GitHub repository secrets and environment variables
- Prefer `GITHUB_TOKEN` over personal access tokens when possible
- Use `environment:` protection rules for production deployments

## Script Guidelines

Scripts in `scripts/` should:

- Start with `#!/usr/bin/env bash`
- Use `set -euo pipefail` for safe execution
- Validate required environment variables before proceeding
- Print clear progress messages
- Exit with meaningful error codes

## Testing Workflows Locally

Use [act](https://github.com/nektos/act) to test workflows locally:

```bash
# Install act
brew install act

# Run a specific workflow
act -W .github/workflows/ci.yml

# Run with specific event
act pull_request -W .github/workflows/pr-check.yml
```

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add Docker build workflow
fix: correct deploy script SSH key path
docs: update workflow descriptions in README
chore: bump action versions
```

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
