# MTaxi deployment boundary

The VPS at 89.126.192.185 is shared with a separate project, **M Business**.
The owner explicitly instructed on 2026-11-02: do not touch M Business at all.
Do not inspect or change its files, repository, containers, database, domains,
certificates, environment or deployment configuration.

Work only on MTaxi. Its deployment uses `/opt/mtaxi`, `/opt/mtaxi-incoming`,
`/var/www/mtaxi`, `/var/lib/mtaxi`, `/var/backups/mtaxi`, `/etc/mtaxi` and Docker
Compose project `mtaxi` with the explicit MTaxi compose files. Preserve unrelated
services. Never use global Docker cleanup, stop-all commands or rewrite shared
configuration to deploy MTaxi. The existing audited GitHub workflow deploys the
MTaxi backend and web without touching other projects.

Do not build or publish APK/AAB unless the user explicitly requests it again;
the current instruction is to update source, web and backend without APK.
