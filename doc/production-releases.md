# Cumulative production releases

Production deploys publish the whole repository, not just the current task's files. Dashboard code previously existed only on codex/weekly-markup-dashboard; deploying master subsequently removed the code while leaving imports in PostgreSQL. Integrate feature changes into master before deployment.

## Release

1. Fetch origin and inspect production `current/REVISION` and `revisions.log` over SSH. Preserve dirty checkouts.
2. Merge the feature into current master, resolve conflicts without discarding other features, and perform relevant checks. Push without force (or use the repository PR process). Re-fetch if master advances.
3. From a clean checkout at the latest master commit run:

   `RBENV_VERSION=2.7.5 bundle exec cap production deploy`

   DEPLOY_REF/BRANCH may name master or its current full SHA; feature branches and stale SHAs are refused.
4. Verify actual current/REVISION, real HTTP access, superadmin dashboard/drilldowns, non-superadmin denial, import counts and delivery endpoint. Do not call a deploy successful solely because files were pushed.

Capistrano obtains a shared atomic directory lock, pins the latest master, checks ancestry of the running release, and rechecks master/current immediately before publication. It refuses a dirty/stale local deployment checkout, missing dashboard/iPhone/KPI files, and non-shared critical configuration. Concurrent guarded deployments cannot publish over each other. Data remains in PostgreSQL; .env and import token remain shared symlinks. There are no destructive data migrations in this restoration.

The lock is `/var/www/itechservice/shared/production-deploy.lock`. Normal success/failure removes only the owning run's lock. If a process is killed, inspect active deployments and server release history before manually clearing a stale lock. Do not automatically expire a live deployment lock.

Automatic rollback to an arbitrary previous release is disabled. For recovery, inspect data/schema compatibility and publish a reviewed revert on master, preserving other released features. Do not roll back the database just to recover UI code.

These checks protect deployments using this repository's current Capistrano code. Old checkouts or manual SSH commands can bypass client-side checks; they are not an access-control boundary. Server credentials must only be used with this release process. GitHub branch protections require separate authenticated repository-admin access; these files do not claim to configure them.
