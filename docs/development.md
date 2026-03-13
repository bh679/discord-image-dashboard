# Development Guide

## Repository Layout

```
Discord Image Aggrigrator/          ← this orchestrator (CI, E2E tests, port registry)
├── discord-image-dashboard-bot/    ← Discord bot (Node.js) — own git remote
├── discord-image-dashboard-client/ ← Web dashboard (frontend) — own git remote
├── docs/                           ← Development documentation
├── tests/                          ← Playwright E2E tests
├── ports/                          ← Port claim files (gitignored *.json)
├── setup.sh                        ← Auto-deployment wizard
└── playwright.config.js
```

The sub-repos (`discord-image-dashboard-bot`, `discord-image-dashboard-client`) are co-located here for convenience but are tracked independently via their own git remotes. They are excluded from this repo's git history via `.gitignore`.

## Sub-repos

| Repo | Description | GitHub |
|---|---|---|
| discord-image-dashboard-bot | Discord bot — listens for image messages and stores them | github.com/bh679/discord-image-dashboard-bot |
| discord-image-dashboard-client | Web dashboard — displays aggregated images | github.com/bh679/discord-image-dashboard-client |

## Local Development

```bash
# Install orchestrator dependencies (Playwright etc.)
npm install

# Run E2E tests
npx playwright test
```

## Workflow

See `CLAUDE.md` for the full three-gate development workflow (Plan → Test → Merge).

## GitHub Project Board

https://github.com/users/bh679/projects/9
