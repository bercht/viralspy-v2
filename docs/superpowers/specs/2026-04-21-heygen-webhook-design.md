# HeyGen Webhook — Design Spec
**Data:** 2026-04-21

## Contexto

O `MediaGeneration::PollWorker` consulta a API da HeyGen a cada 10s por até 10 min para saber se o vídeo ficou pronto. O webhook substitui esse polling como caminho principal — a HeyGen notifica o sistema assim que o vídeo é concluído. O PollWorker permanece como fallback de segurança.

## Abordagem

Webhook principal + PollWorker como fallback. Se o webhook falhar por qualquer motivo, o poll garante que o status seja atualizado. O PollWorker não precisa de modificação — a verificação de skip já existe no início do `perform`.

## Endpoint

```
POST /webhooks/heygen
```

- Fora de qualquer namespace autenticado (sem Devise, sem `acts_as_tenant`)
- Sem proteção CSRF (`skip_before_action :verify_authenticity_token`)
- Responde 200 em todos os casos válidos — HeyGen retenta se não receber 200

### Rota exata em `config/routes.rb`

Adicionar fora de qualquer scope autenticado:

```ruby
# Webhooks externos — sem autenticação Devise, sem tenant
namespace :webhooks do
  post :heygen, to: "heygen#receive"
end
```

## Verificação de Assinatura

A HeyGen assina o payload com HMAC-SHA256 usando o webhook secret configurado no dashboard. O controller verifica a assinatura no header `X-Signature` antes de processar qualquer dado:

```ruby
expected = OpenSSL::HMAC.hexdigest("SHA256", secret, raw_body)
```

> **Instrução ao implementar:** o nome do header padrão usado aqui é `X-Signature`. Ao criar o webhook no dashboard HeyGen, confirmar o nome exato do header de assinatura. Se for diferente (ex: `X-Heygen-Signature`), ajustar a constante no controller **antes de fazer deploy**.

- Assinatura inválida → 401, sem processar
- Secret ausente no ENV → log de erro + 500

## Payload HeyGen (evento `video_status`)

> **Instrução ao implementar:** confirmar a estrutura exata do payload no dashboard HeyGen ao criar o webhook. A estrutura abaixo é a esperada com base na documentação disponível — ajustar extração de campos se necessário.

```json
{
  "event_type": "video_status",
  "event_data": {
    "video_id": "abc123",
    "status": "completed",
    "video_url": "https://...",
    "error": null
  }
}
```

Status possíveis: `completed`, `failed`. Status intermediários (`pending`, `processing`) são ignorados — o poll já cobre esses.

## Fluxo de Processamento

1. HeyGen faz `POST /webhooks/heygen`
2. Controller lê o raw body **antes** de qualquer parse (obrigatório para HMAC)
3. Verifica assinatura HMAC — 401 se inválida
4. Parseia JSON e extrai `event_type`, `video_id`, `status`, `video_url`, `error`
5. Ignora eventos que não sejam `video_status` → 200 (sem processar)
6. Busca `GeneratedMedia` por `provider_job_id = video_id` sem tenant:
   ```ruby
   # Webhook não carrega tenant — busca global necessária para encontrar o registro
   ActsAsTenant.without_tenant { GeneratedMedia.find_by(provider_job_id: video_id) }
   ```
7. Se não encontrado → log de warning + 200 (pode ser de outro ambiente ou job antigo)
8. Se já `completed` ou `failed` → 200 (idempotente, sem reprocessar)
9. Se `completed`:
   - Atualiza `status: :completed`, `output_url`, `finished_at`
   - Cria `MediaGenerationUsageLog`
   - Broadcast Turbo Stream
10. Se `failed`:
    - Atualiza `status: :failed`, `error_message`, `finished_at`
    - Broadcast Turbo Stream
11. Responde 200

## PollWorker

Nenhuma modificação necessária. A verificação `return if generated_media.completed? || generated_media.failed?` já existe no início do `perform` — o webhook apenas acelera a resolução, o poll continua como fallback sem mudança de lógica.

## Variável de Ambiente

| Variável | Descrição |
|---|---|
| `HEYGEN_WEBHOOK_SECRET` | Secret gerado pelo dashboard HeyGen ao criar o webhook endpoint |

Adicionar ao `.env.example` com valor vazio.

## Configuração na HeyGen

No dashboard HeyGen → Settings → Webhooks:
- URL: `https://viralspy.curt.com.br/webhooks/heygen`
- Eventos: `video_status` (ou equivalente na UI)
- Copiar o secret gerado para `HEYGEN_WEBHOOK_SECRET` no servidor

## Arquivos Novos

- `app/controllers/webhooks/heygen_controller.rb`
- `spec/requests/webhooks/heygen_spec.rb`

## Arquivos Modificados

- `config/routes.rb` — adicionar bloco `namespace :webhooks`
- `.env.example` — adicionar `HEYGEN_WEBHOOK_SECRET=`

## Arquivos NÃO modificados

- `app/workers/media_generation/poll_worker.rb`
- `app/models/generated_media.rb`

## Testes

Spec de request em `spec/requests/webhooks/heygen_spec.rb`. Casos obrigatórios:

| Caso | Resultado esperado |
|---|---|
| Assinatura válida + `completed` | 200, GeneratedMedia atualizado, Turbo broadcast |
| Assinatura válida + `failed` | 200, GeneratedMedia atualizado com error_message |
| Assinatura inválida | 401, sem efeito no banco |
| Evento desconhecido | 200, sem efeito |
| `video_id` não encontrado | 200, sem efeito, log de warning |
| Já `completed` (reentrada) | 200, sem reprocessamento (idempotência) |

- WebMock basta — webhook é inbound, sem chamadas externas no controller
- Sem VCR necessário
