# HeyGen Webhook — Design Spec
**Data:** 2026-04-21

## Contexto

O `MediaGeneration::PollWorker` consulta a API da HeyGen a cada 10s por até 10 min para saber se o vídeo ficou pronto. O webhook substitui esse polling como caminho principal — a HeyGen notifica o sistema assim que o vídeo é concluído. O PollWorker permanece como fallback de segurança.

## Abordagem

Webhook principal + PollWorker como fallback. Se o webhook falhar por qualquer motivo, o poll garante que o status seja atualizado. O PollWorker é ajustado para pular chamadas à API quando o GeneratedMedia já foi resolvido pelo webhook.

## Endpoint

```
POST /webhooks/heygen
```

- Fora de qualquer namespace autenticado (sem Devise, sem `acts_as_tenant`)
- Sem proteção CSRF (`skip_before_action :verify_authenticity_token`)
- Responde 200 em todos os casos válidos — HeyGen retenta se não receber 200

## Verificação de Assinatura

A HeyGen assina o payload com HMAC-SHA256 usando o webhook secret configurado no dashboard. O controller verifica a assinatura no header `X-Signature` antes de processar qualquer dado:

```
expected = OpenSSL::HMAC.hexdigest("SHA256", secret, raw_body)
```

- Assinatura inválida → 401, sem processar
- Secret ausente no ENV → log de erro + 500

## Payload HeyGen (evento `video_status`)

> **Nota de implementação:** verificar o nome exato do header de assinatura e a estrutura do payload na HeyGen dashboard ao criar o webhook — podem diferir levemente do documentado aqui.


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
2. Controller lê o raw body antes de qualquer parse
3. Verifica assinatura HMAC — 401 se inválida
4. Parseia JSON e extrai `event_type`, `video_id`, `status`, `video_url`, `error`
5. Ignora eventos que não sejam `video_status` → 200 (sem processar)
6. Busca `GeneratedMedia` por `provider_job_id = video_id` sem tenant (`ActsAsTenant.without_tenant`)
7. Se não encontrado → log de warning + 200 (pode ser de outro ambiente)
8. Se já `completed` ou `failed` → 200 (idempotente, sem reprocessar)
9. Se `completed`:
   - Atualiza `status: :completed`, `output_url`, `finished_at`
   - Cria `MediaGenerationUsageLog`
   - Broadcast Turbo Stream
10. Se `failed`:
    - Atualiza `status: :failed`, `error_message`, `finished_at`
    - Broadcast Turbo Stream
11. Responde 200

## PollWorker — Ajuste

No início do `perform`, antes de qualquer chamada à API, verificar se o registro já foi resolvido:

```ruby
return if generated_media.completed? || generated_media.failed?
```

Essa verificação já existe. O comportamento atual está correto — o webhook apenas acelera a resolução, o poll continua como fallback sem mudança de lógica.

## Variável de Ambiente

| Variável | Descrição |
|---|---|
| `HEYGEN_WEBHOOK_SECRET` | Secret configurado no dashboard HeyGen ao criar o webhook |

Adicionar ao `.env.example` com valor vazio.

## Configuração na HeyGen

No dashboard HeyGen → Settings → Webhooks:
- URL: `https://viralspy.curt.com.br/webhooks/heygen`
- Eventos: `video_status` (ou equivalente na UI deles)
- Copiar o secret gerado para `HEYGEN_WEBHOOK_SECRET` no servidor

## Arquivos Novos

- `app/controllers/webhooks/heygen_controller.rb`

## Arquivos Modificados

- `config/routes.rb` — adicionar rota do webhook fora de namespaces autenticados
- `.env.example` — adicionar `HEYGEN_WEBHOOK_SECRET=`

## Arquivos NÃO modificados

- `app/workers/media_generation/poll_worker.rb` — já tem a verificação de skip no início, nenhuma mudança necessária
- `app/models/generated_media.rb` — nenhuma mudança necessária

## Testes

- Spec de request em `spec/requests/webhooks/heygen_spec.rb`
- Casos: assinatura válida + completed, assinatura válida + failed, assinatura inválida (401), evento desconhecido (200 sem efeito), GeneratedMedia não encontrado (200 sem efeito), idempotência (já completed)
- Usar WebMock para isolar chamadas externas; sem VCR necessário (webhook é inbound)
