# Production releases

- Production is https://ise.itech.pw; the shared repository is git@github.com:itechdevelopers/iTechService.git.
- All Codex changes intended for production must be integrated into the current origin/master before deploying. A successful feature-branch deployment is not completion.
- Fetch first, use an isolated worktree, preserve other work, and merge current production history and current master. Never force-push master, reset another checkout, or replace production with an older feature branch.
- Deploy from a clean checkout whose HEAD equals the latest origin/master with `RBENV_VERSION=2.7.5 bundle exec cap production deploy`. Do not bypass the production safety tasks or use an old checkout without them.
- The deploy locks production, pins master, requires running production to be an ancestor, and checks again before switching releases. A failed check must be investigated, not disabled. A lock remaining after a killed process may only be removed after confirming no deployment is running.
- Keep database data, import history, uploads, .env and import tokens in shared storage. Never restore a database or rerun seed tasks merely to restore missing UI code.
- Verify dashboard, iPhone detail, KPI, existing production features, access restrictions and import counts after deployment. Record the deployed SHA and checks. See doc/production-releases.md.
- 1C access remains read-only GET. AIS import writes are separate from 1C and must retain immutable versions/idempotency.
