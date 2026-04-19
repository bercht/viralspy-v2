# Deploy — ViralSpy v2

Passo-a-passo pra primeiro deploy em produção. Seguir uma vez. Depois, deploys rotineiros usam só `bin/deploy` da máquina local.

---

## Pré-requisitos

Antes de começar, validar no VPS:

```bash
ssh deployer@72.60.152.144

# Traefik rodando
docker ps | grep traefik

# Network web existe
docker network ls | grep web

# Diretório base existe
ls -la /home/deployer/
```

Se algum desses falhar, configurar Traefik antes de continuar.

---

## Passo 1 — Instalar aws-cli no VPS (para backups)

```bash
ssh deployer@72.60.152.144
sudo apt-get update
sudo apt-get install -y awscli
aws --version  # esperado: aws-cli/1.x ou 2.x
```

---

## Passo 2 — Clone e setup inicial

Apps no VPS ficam em `/opt/apps/<nome>/`, seguindo o padrão já estabelecido pelo Fifty e outros apps.

```bash
# No VPS, garantir que /opt/apps é gravável pelo deployer
# (rodar uma vez, se ainda não estiver configurado)
sudo mkdir -p /opt/apps
sudo chown deployer:deployer /opt/apps

# Clone
cd /opt/apps
git clone git@github.com:curtbercht/viralspy-v2.git
cd viralspy-v2

# Copia template de env
cp .env.example .env.production
chmod 600 .env.production
```

---

## Passo 3 — Preencher .env.production

```bash
nano .env.production
```

### Postgres

```bash
POSTGRES_USER=viralspy
POSTGRES_PASSWORD=<gerar senha forte: openssl rand -hex 24>
POSTGRES_DB=viralspy_production
```

### Rails

```bash
# Obter da master.key local: cat config/master.key
RAILS_MASTER_KEY=<cole o valor de config/master.key>

# Gerar novo: openssl rand -hex 64
SECRET_KEY_BASE=<64 hex chars>

VIRALSPY_HOST=viralspy.curt.com.br
```

### APIs externas

```bash
APIFY_API_TOKEN=<real>
OPENAI_API_KEY=<real>
ANTHROPIC_API_KEY=<real>
```

### Active Record Encryption

```bash
# Gerar com: bundle exec rails db:encryption:init
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=<valor>
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=<valor>
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=<valor>
```

### Cloudflare R2

R2 é S3-compatible, free tier 10GB (folgado pra backup do MVP), egress grátis.

1. **Acessar dashboard R2:** https://dash.cloudflare.com → conta → sidebar "R2"
2. **Criar bucket:**
   - Clicar "Create bucket"
   - Nome: `viralspy-backups`
   - Location: `Automatic` (default)
   - Criar
3. **Gerar API token:**
   - Em R2, clicar "Manage R2 API Tokens" (topo da página) → "Create API Token"
   - ⚠️ **Não confundir** com "My Profile → API Tokens" (tokens gerais do Cloudflare não funcionam em R2)
   - Permissions: `Object Read & Write`
   - Specify bucket(s): selecionar apenas `viralspy-backups` (não dar acesso a todos)
   - TTL: leave forever (ou data fixa conforme política de rotação de credenciais)
   - Criar → copiar **Access Key ID** e **Secret Access Key** (aparecem uma única vez)
4. **Anotar o endpoint:** está na tela do bucket após criação, no formato:
   `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`
   onde `<ACCOUNT_ID>` é um hash hexadecimal de 32 caracteres.

Preencher no `.env.production`:

```bash
BACKUP_S3_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
BACKUP_S3_ACCESS_KEY=<access key id>
BACKUP_S3_SECRET_KEY=<secret access key>
BACKUP_S3_BUCKET=viralspy-backups
BACKUP_S3_REGION=auto
```

> **Atenção:** `BACKUP_S3_REGION=auto` é a string literal `auto`, não é placeholder. R2 não usa regiões AWS-style.

### Testar conectividade S3

```bash
set -a; source .env.production; set +a
AWS_ACCESS_KEY_ID="$BACKUP_S3_ACCESS_KEY" \
AWS_SECRET_ACCESS_KEY="$BACKUP_S3_SECRET_KEY" \
aws --endpoint-url "$BACKUP_S3_ENDPOINT" \
    --region "$BACKUP_S3_REGION" \
    s3 ls "s3://$BACKUP_S3_BUCKET/"
```

Deve retornar vazio (bucket vazio ainda) ou lista. Se der erro, revisar credenciais.

---

## Passo 4 — Primeira build

```bash
cd /opt/apps/viralspy-v2
docker compose --env-file .env.production build
```

Leva 3-5 min. Não deve dar erro.

---

## Passo 5 — Subir serviços

```bash
docker compose --env-file .env.production up -d
```

Verificar:

```bash
docker compose --env-file .env.production ps
# Esperado: db, redis, web, sidekiq todos em "healthy" ou "running"

docker compose --env-file .env.production logs -f web
# Esperado: "Puma starting..." e healthcheck respondendo
# Ctrl+C quando ver "Running in production mode"
```

---

## Passo 6 — Verificar externamente

No laptop (fora do VPS):

```bash
curl -I https://viralspy.curt.com.br/up
# Esperado: HTTP/2 200
# Primeira request pode demorar 15-30s (Let's Encrypt emitindo cert)

curl -I https://viralspy.curt.com.br/users/sign_in
# Esperado: HTTP/2 200
```

Abrir no browser: `https://viralspy.curt.com.br` — deve redirecionar pro login do Devise.

---

## Passo 7 — Criar primeira conta

Pelo browser, fazer signup normal. Depois verificar no VPS:

```bash
docker compose --env-file .env.production exec web bin/rails runner "puts Account.count; puts User.count"
```

---

## Passo 8 — Configurar cron de backup

Criar diretório de backups locais e log com permissões corretas:

```bash
# Diretório pra dumps locais (antes de upload S3)
sudo mkdir -p /var/backups/viralspy-v2
sudo chown deployer:deployer /var/backups/viralspy-v2

# Log do cron
sudo touch /var/log/viralspy-backup.log
sudo chown deployer:deployer /var/log/viralspy-backup.log

# Agora o cron
crontab -e
```

Adicionar:

```
0 3 * * * /opt/apps/viralspy-v2/bin/backup >> /var/log/viralspy-backup.log 2>&1
```

Testar manualmente:

```bash
/opt/apps/viralspy-v2/bin/backup
tail /var/log/viralspy-backup.log
```

Verificar no bucket R2 que apareceu `viralspy_<timestamp>.sql.gz`.

---

## Passo 9 — Rodar primeira análise real

Pelo browser logado:

1. Adicionar competitor (ex: `@algum_corretor_real`)
2. Clicar em "Nova análise"
3. Aguardar 3-4 min
4. Refresh → ver resultado

Se algo falhar, logs:

```bash
docker compose --env-file .env.production logs -f sidekiq
docker compose --env-file .env.production logs -f web
```

---

## Deploys subsequentes (rotineiros)

A partir daqui, deploys são **da máquina local**:

```bash
# No laptop, branch main commitada
bin/deploy
```

Script faz tudo: valida branch limpa, push pro GitHub, SSH no VPS, git pull, build, up -d, healthcheck.

Duração esperada: 2-4 min (depende de quanto mudou e se gem nova).

---

## Disaster recovery

### Rollback de deploy ruim

```bash
ssh deployer@72.60.152.144
cd /opt/apps/viralspy-v2
git log --oneline -5                # ver commits recentes
git reset --hard <commit-anterior>
docker compose --env-file .env.production build web sidekiq
docker compose --env-file .env.production up -d
```

### Restore de backup

```bash
ssh deployer@72.60.152.144
cd /opt/apps/viralspy-v2

# Listar backups disponíveis
set -a; source .env.production; set +a
AWS_ACCESS_KEY_ID="$BACKUP_S3_ACCESS_KEY" \
AWS_SECRET_ACCESS_KEY="$BACKUP_S3_SECRET_KEY" \
aws --endpoint-url "$BACKUP_S3_ENDPOINT" \
    --region "$BACKUP_S3_REGION" \
    s3 ls "s3://$BACKUP_S3_BUCKET/"

# Restaurar um específico
bin/restore-backup s3 viralspy_20260420_030000.sql.gz
```

---

## Troubleshooting

### "502 Bad Gateway" do Traefik

Container `web` não está respondendo:

```bash
docker compose --env-file .env.production logs --tail=100 web
docker compose --env-file .env.production ps
```

### Análise fica em "pending" pra sempre

Sidekiq não está rodando:

```bash
docker compose --env-file .env.production logs sidekiq
docker compose --env-file .env.production restart sidekiq
```

### "TLS handshake error"

Let's Encrypt ainda emitindo cert. Aguardar 30s e tentar de novo.

### Banco não migra automaticamente

```bash
docker compose --env-file .env.production exec web bin/rails db:migrate:status
docker compose --env-file .env.production exec web bin/rails db:migrate
```

### Limpar tudo e recomeçar do zero (CUIDADO — apaga banco)

```bash
docker compose --env-file .env.production down -v  # apaga volumes!
docker compose --env-file .env.production build
docker compose --env-file .env.production up -d
```

Só fazer se já tiver backup válido e estiver ok em perder dados.
