# PayGate

Manual payment-collection platform (Admin · Partners · Branches).

Stack: Laravel 13 · PHP 8.5 (FrankenPHP) · PostgreSQL 18 · Redis 8 + Horizon · React/TypeScript via Inertia.

**This is the live server: https://a27pay.com** (`PAYGATE_ENVIRONMENT=live`, real money).
Deploy a new version with `bash <APP_DIR>/scripts/deploy-live.sh` (set `APP_USER` / `APP_DIR` in that script first).

| Server  | Address     | Repository    | `PAYGATE_ENVIRONMENT` |
| ------- | ----------- | ------------- | --------------------- |
| Live    | a27pay.com  | vrogitlive    | `live`                |
| Sandbox | a27pay.tech | vrogitstaging | `sandbox`             |

Changes are made and tested on the sandbox first, then copied here. Never run `TestPartnerSeeder` or the
`paygate:test-*` commands here: they refuse on live. Before each deploy, `php artisan paygate:key-environments`
lists partner keys this server would refuse.

## Local development (Docker)

The Docker stack (`compose.yaml`, `Makefile`, `docker/`) and the project documents (`Document/`) are kept
on the developer's machine only and are not in this repository.

```bash
sudo sh -c 'echo "127.0.0.1 a27pay.local api.a27pay.local pay.a27pay.local" >> /etc/hosts'
make setup
```

| URL                         | What               | Login                                     |
| --------------------------- | ------------------ | ----------------------------------------- |
| http://a27pay.local         | Portals            | `admin@a27pay.local` / `password`         |
| http://localhost:8080       | Adminer (database) | `paygate` / `secret`, database `paygate`  |
| http://localhost:8025       | Mailpit (emails)   | none                                      |
| http://a27pay.local/horizon | Queues             | none (local)                              |

`make help` lists all commands.
