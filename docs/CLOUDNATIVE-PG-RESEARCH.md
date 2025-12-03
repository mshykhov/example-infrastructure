# CloudNativePG Research Notes

## Overview

CloudNativePG — CNCF Incubating project для управления PostgreSQL в Kubernetes.

**Официальная документация:** https://cloudnative-pg.io/documentation/current/

---

## Secrets Management

### Автоматически генерируемые секреты

CloudNativePG создаёт два типа секретов для каждого кластера:

| Secret | Назначение |
|--------|-----------|
| `<cluster>-app` | Для приложений (application user) |
| `<cluster>-superuser` | Для администрирования (postgres user) |

### Содержимое `-app` секрета

```
username        - имя пользователя
password        - пароль
hostname        - адрес RW сервиса
port            - порт (5432)
dbname          - имя базы данных
uri             - PostgreSQL connection string
jdbc-uri        - JDBC connection string (для Spring Boot!)
pgpass          - .pgpass файл
```

### Рекомендация по секретам

**Использовать CloudNativePG secrets — официальный подход:**
- Пароли генерируются автоматически (secure random)
- jdbc-uri готов для Spring Boot
- Секрет в том же namespace — простой доступ

**Doppler оставить для:**
- AUTH0, OVH S3, внешние API ключи
- НЕ для DB credentials (двойное управление = рассинхрон)

---

## Доступ к базе данных

### Официальный способ: kubectl cnpg plugin

**Установка:**
```bash
# Через Krew
kubectl krew install cnpg

# Или через скрипт
curl -sSfL \
  https://github.com/cloudnative-pg/cloudnative-pg/raw/main/hack/install-cnpg-plugin.sh | \
  sudo sh -s -- -b /usr/local/bin
```

**Основные команды:**
```bash
# Статус кластера
kubectl cnpg status <cluster> -n <namespace>
kubectl cnpg status <cluster> -n <namespace> -v     # verbose
kubectl cnpg status <cluster> -n <namespace> -v -v  # very verbose (+ configs, HBA, certs)

# Подключение к psql (автоматически использует credentials)
kubectl cnpg psql <cluster> -n <namespace>
kubectl cnpg psql <cluster> -n <namespace> --replica  # к read-only реплике

# Генерация клиентского сертификата
kubectl cnpg certificate <secret-name> \
  --cnpg-cluster <cluster> \
  --cnpg-user <username> \
  -n <namespace>

# Restart/Reload
kubectl cnpg restart <cluster> -n <namespace>  # rolling restart
kubectl cnpg reload <cluster> -n <namespace>   # reload configs

# Promote (switchover)
kubectl cnpg promote <cluster> <instance> -n <namespace>
```

### Альтернативные способы (менее предпочтительные)

```bash
# Через kubectl get secret
kubectl get secret <cluster>-app -n <namespace> -o jsonpath='{.data.jdbc-uri}' | base64 -d

# Через port-forward
kubectl port-forward svc/<cluster>-rw -n <namespace> 5432:5432

# Через exec в pod
kubectl exec -it <cluster>-1 -n <namespace> -- psql -U postgres
```

---

## Backup Configuration

### Методы бэкапа (v1.26+)

| Метод | WAL Archive | Hot Backup | Incremental | Retention |
|-------|-------------|------------|-------------|-----------|
| Object Store (Barman) | Required | ✅ | ❌ | ✅ |
| Volume Snapshots | Recommended | ✅ | ✅ | ❌ |
| Barman Cloud Plugin | Required | ✅ | ❌ | ✅ |

### Рекомендация для Production

> "Our recommendation is to always setup the WAL archive in production."

### Пример конфигурации бэкапа в OVH S3

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
spec:
  backup:
    barmanObjectStore:
      destinationPath: s3://postgres-backups/
      endpointURL: https://s3.gra.io.cloud.ovh.net
      s3Credentials:
        accessKeyId:
          name: ovh-s3-creds
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: ovh-s3-creds
          key: SECRET_ACCESS_KEY
    retentionPolicy: "7d"
```

### ScheduledBackup пример

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: backup-daily
spec:
  schedule: "0 0 0 * * *"  # At midnight every day (6-field cron with seconds!)
  backupOwnerReference: self
  cluster:
    name: example-api-db-prd
```

---

## Connection Pooling (PgBouncer)

CloudNativePG поддерживает PgBouncer через `Pooler` CRD:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Pooler
metadata:
  name: example-api-db-pooler-rw
spec:
  cluster:
    name: example-api-db-dev
  instances: 3
  type: rw  # или ro для read-only
  pgbouncer:
    poolMode: session  # session, transaction, statement
    parameters:
      max_client_conn: "1000"
      default_pool_size: "10"
```

**Когда использовать:**
- Много короткоживущих соединений
- Нужен connection reuse
- High concurrency

---

## Services

CloudNativePG создаёт сервисы:

| Service | Назначение |
|---------|-----------|
| `<cluster>-rw` | Read-Write (primary) |
| `<cluster>-ro` | Read-Only (replicas) |
| `<cluster>-r` | Read (any instance) |

---

## Текущая структура проекта

### example-infrastructure

```
apps/templates/core/cloudnative-pg.yaml     # Operator (v0.26.1)
apps/templates/data/postgres-clusters.yaml  # ApplicationSet для DB кластеров
helm-values/core/cloudnative-pg.yaml        # Operator values
helm-values/data/postgres-dev-defaults.yaml # DEV defaults (1 instance)
helm-values/data/postgres-prd-defaults.yaml # PRD defaults (3 instances)
```

### example-deploy

```
databases/example-api/values.yaml  # Per-service DB config (10Gi, initdb)
```

### Secret naming convention

```
Cluster name: example-api-db-{env}
Secret name:  example-api-db-{env}-app
```

---

## TODO

- [ ] Добавить JPA config в example-api application.yaml
- [ ] Создать Flyway миграцию V1__init.sql
- [ ] Настроить backup в OVH S3 для PRD
- [ ] Рассмотреть PgBouncer для production
- [ ] Установить kubectl cnpg plugin на рабочую машину

---

## Sources

- https://cloudnative-pg.io/documentation/current/
- https://cloudnative-pg.io/documentation/current/applications/
- https://cloudnative-pg.io/documentation/current/bootstrap/
- https://cloudnative-pg.io/documentation/current/backup/
- https://cloudnative-pg.io/documentation/current/connection_pooling/
- https://cloudnative-pg.io/documentation/current/kubectl-plugin/
- https://cloudnative-pg.io/documentation/current/security/
