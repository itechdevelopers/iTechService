# Cumulative production releases

Production deploys publish the whole repository, not just the current task's files. Dashboard code previously existed only on codex/weekly-markup-dashboard; deploying master subsequently removed the code while leaving imports in PostgreSQL. Integrate feature changes into master before deployment.

## Release

1. Fetch origin and inspect production `current/REVISION` and `revisions.log` over SSH. Preserve dirty checkouts.
2. Merge the feature into current master, resolve conflicts without discarding other features, and perform relevant checks. Push without force (or use the repository PR process). Re-fetch if master advances.
3. From a clean checkout at the latest master commit run:

   `RBENV_VERSION=2.7.5 bundle exec cap production deploy`

   DEPLOY_REF/BRANCH may name master or its current full SHA; feature branches and stale SHAs are refused.
4. Verify actual current/REVISION, real HTTP access, superadmin dashboard/drilldowns, non-superadmin denial, import counts and delivery endpoint. Do not call a deploy successful solely because files were pushed.

Capistrano obtains a shared atomic directory lock, pins the latest master, checks ancestry of the running release, and rechecks master/current immediately before publication. It refuses a dirty or stale local deployment checkout. Concurrent guarded deployments cannot publish over each other. Data remains in PostgreSQL; `.env` and the import token remain shared symlinks — their presence is enforced by Capistrano's own `deploy:check:linked_files`, which aborts the deploy before anything is built.

The lock is `/var/www/itechservice/shared/production-deploy.lock`. Its `owner` file names the operator, host, UTC timestamp and pid, so a busy lock can be traced with `cat …/production-deploy.lock/owner`. Normal success/failure removes only the owning run's lock. If a process is killed, inspect active deployments and server release history before manually clearing a stale lock. Do not automatically expire a live deployment lock.

Rollback to a previous release is refused by default: the symlink moves back, but the database schema does not, so an older release can meet migrations it does not know about. For recovery, prefer publishing a reviewed revert on master. When the schema is known to be compatible, `ALLOW_PRODUCTION_ROLLBACK=1` re-enables `deploy:rollback` for that run. Do not roll back the database just to recover UI code.

These checks protect deployments using this repository's current Capistrano code. Old checkouts or manual SSH commands can bypass client-side checks; they are not an access-control boundary. Server credentials must only be used with this release process. GitHub branch protections require separate authenticated repository-admin access; these files do not claim to configure them.
