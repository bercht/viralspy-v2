# 00_NORTE — Visão e Direção do ViralSpy v2

> Este documento é o norte do produto. Toda decisão deve ser coerente com o que está aqui. Se algo contradiz este documento, este documento prevalece até ser explicitamente atualizado pelo Curt.

---

## O que é o ViralSpy v2

Plataforma SaaS que ajuda criadores de conteúdo e profissionais do mercado imobiliário brasileiro a crescer no Instagram, a partir da análise sistemática de concorrentes e do acompanhamento da evolução do próprio perfil.

**Promessa central:** o usuário não precisa inventar do zero o que postar. A ferramenta analisa o que está funcionando nos nichos relevantes e entrega sugestões prontas, contextualizadas, com gancho, caption e formato definidos — alimentando uma base de conhecimento viva que fica mais inteligente a cada análise.

---

## Quem usa

O produto atende qualquer criador de conteúdo no Instagram que queira crescer de forma sistemática, com foco inicial no mercado imobiliário brasileiro. Os perfis de usuário variam em nicho:

**Perfil A — Educador/Influencer imobiliário**
- Ensina corretores e profissionais do setor
- Nicho: marketing imobiliário, IA aplicada, educação
- Analisa perfis de educadores, influencers de IA, marketing digital
- Exemplo: perfil de marketing imobiliário com IA

**Perfil B — Corretor autônomo**
- Trabalha sozinho ou em equipe pequena
- Instagram é o principal canal de captação
- Não tem estrutura de marketing
- Analisa concorrentes diretos no nicho imobiliário local

**Perfil C — Imobiliária estruturada / SaaS imobiliário**
- Tem equipe, portfólio, presença consolidada
- Usa Fifty CRM (integração futura)
- Pode ter múltiplos perfis Instagram a gerenciar

**No MVP, todos os perfis são atendidos com o mesmo produto.** A flexibilidade vem dos Playbooks — cada usuário configura seus próprios nichos de análise.

---

## O problema que resolve

Qualquer criador de conteúdo que quer crescer no Instagram tem três dores:

1. **Não sabe o que postar.** Copia ideias aleatórias, inventa quando tem tempo, pula dias quando não tem.
2. **Analisa concorrente de forma manual e rasa.** Olha um ou dois perfis, pega ideia solta, não tem processo sistemático.
3. **Não aprende com o próprio histórico.** Não sabe por que um post foi bem e outro foi mal. Não acumula conhecimento.

ViralSpy v2 automatiza a análise de concorrentes, transforma o resultado em sugestões estruturadas, e acumula tudo em uma base de conhecimento viva que fica mais inteligente com cada análise e com cada post publicado.

---

## O que é SUCESSO para o MVP

Métricas mínimas viáveis pra considerar o MVP validado:

- **20 contas pagantes** em até 90 dias após lançamento público
- **50% de retenção** no segundo mês (paga de novo)
- **NPS ≥ 40**
- **≥ 3 análises/mês por conta ativa** (indica uso real, não só cadastro)

Se não bater pelo menos 3 dessas 4 métricas, o produto precisa ser repensado antes de escalar.

---

## Diferencial competitivo defensável

Contra concorrentes diretos (ferramentas genéricas de análise Instagram, ferramentas de gen conteúdo IA, consultorias manuais):

1. **Playbook vivo por nicho.** Conhecimento acumula a cada análise — o produto fica mais inteligente com o uso, não começa do zero toda vez.
2. **Análise sistemática + geração em uma ferramenta.** Ninguém faz os dois bem integrados.
3. **Loop de resultado real.** Compara sugestão gerada com o que foi postado e o que funcionou — aprende com a prática, não só com teoria de concorrente.
4. **Flexibilidade de nicho.** Múltiplos Playbooks por conta — cada nicho, cada cliente, cada propósito com base de conhecimento separada.
5. **BYOK (Bring Your Own Keys).** Usuário usa suas próprias chaves de API — controle total de custo e provider.
6. **Integração com Fifty CRM (futuro).** Fluxo completo: análise de concorrente → conteúdo → lead no CRM.

---

## Não-objetivos explícitos

Coisas que o produto NÃO faz e NÃO vai fazer (no MVP e próximas 3 fases):

- ❌ **Agendamento e publicação automática.** Usuário copia e posta manualmente. (Pode virar feature na Fase 4+.)
- ❌ **Geração de imagem/vídeo com IA.** Caption e formato sugerido sim. Criar a arte é com o usuário. (Fase 4+ talvez.)
- ❌ **Dashboard de CRM/leads.** Isso é o Fifty, não o ViralSpy.
- ❌ **WhatsApp / DM automação.** Isso é o Fifty, não o ViralSpy.
- ❌ **Monitoramento contínuo automático de concorrentes.** Usuário dispara análise quando quer. Scheduling recorrente é Fase 2+.
- ❌ **Multi-usuário por conta (times).** No MVP, 1 usuário por conta. Multi-usuário pode ser Fase 2+.
- ❌ **Scraping de stories de concorrentes.** Inviável tecnicamente de forma confiável. Stories de concorrentes são registrados manualmente pelo usuário.
- ❌ **Chaves API do servidor para LLM.** Cada usuário traz suas próprias chaves (BYOK). Único exception: Apify (scraping) é responsabilidade da plataforma.

---

## Modelo de API Keys (BYOK)

**Cada usuário traz suas próprias chaves de API.** O ViralSpy não paga nem centraliza chamadas de IA.

- **OpenAI:** opcional — usuário escolhe entre OpenAI e Anthropic pra análise estruturada e geração de conteúdo. Se escolher OpenAI, precisa da chave.
- **Anthropic:** opcional — idem.
- **AssemblyAI:** opcional — usuário escolhe entre OpenAI e AssemblyAI pra transcrição. Default do sistema: AssemblyAI (free tier $50 no signup).
- **Apify:** chave da plataforma (scraping é responsabilidade do ViralSpy, não BYOK).

Requisito mínimo pra rodar análise: 1 credential ativa do provider configurado em cada use_case (transcrição, análise, geração). Usuário configura em Configurações → API Keys. Chaves encryptadas no banco (ADR-006). Onboarding gate bloqueia análise se faltar credential.

---

## Sistema de Playbooks

Cada conta pode ter **múltiplos Playbooks** — bases de conhecimento independentes, cada uma com nicho, conjunto de concorrentes e perfil próprio distintos.

**Exemplos de uso:**
- Playbook "Marketing com IA" → analisa influencers de IA e marketing → vinculado ao perfil pessoal
- Playbook "Fifty" → analisa SaaS imobiliários concorrentes → vinculado ao perfil do Fifty
- Playbook "Corretores" → analisa corretores de imóveis → pesquisa pura (sem perfil próprio vinculado, insights usados como pauta)

A cada análise, o usuário escolhe em quais Playbooks ela contribui (planejado para roadmap futuro — associação de análise a Playbooks ainda não implementada; hoje cada análise é independente). Uma análise pode alimentar múltiplos Playbooks se o conteúdo for relevante pra mais de um nicho.

---

## Princípios de produto

Decisões ambíguas devem ser resolvidas favorecendo estes princípios, nesta ordem:

1. **Simplicidade para o usuário iniciante.** Se uma feature exige conhecimento técnico do usuário, ela está mal desenhada.
2. **Qualidade do output da IA sobre quantidade de features.** 5 sugestões excelentes > 20 sugestões medianas.
3. **Custo marginal zero em IA.** BYOK garante que escala não aumenta custo operacional do produto.
4. **Autonomia do usuário após onboarding.** Sem depender de suporte humano para uso diário.
5. **Playbook como diferencial.** O produto fica mais valioso com o uso — não é commodity.
6. **Integração nativa com Fifty quando o usuário é cliente dos dois.**

---

## Relação com o Fifty CRM

**ViralSpy v2 é produto separado. Não é módulo do Fifty.**

- Aplicações Rails separadas, bancos separados, Docker containers separados, domínios separados
- Infraestrutura compartilhada (mesmo VPS, Traefik, Cloudflare)
- Integração futura via API REST com token de serviço (não SSO, não DB compartilhado)
- Fluxo de integração alvo: Fifty envia imóvel para ViralSpy → ViralSpy gera conteúdo contextualizado → usuário publica

No MVP, **a integração NÃO é implementada**. Integração com Fifty será avaliada em roadmap futuro — no repo atual não há scaffold técnico (`/api/v1/`, `ApiToken`, serializers).

---

## Monetização (hipótese inicial)

Planos provisórios (ajustar conforme validação):

- **Free / Trial:** 1 análise gratuita para testar (requer chaves próprias)
- **Starter:** R$ 79/mês — 10 análises/mês, 2 Playbooks
- **Pro:** R$ 149/mês — 40 análises/mês, Playbooks ilimitados, perfil próprio (Meta Graph API)
- **Agência:** R$ 299/mês — análises ilimitadas + integração Fifty + múltiplos perfis próprios

Billing via Stripe (mesmo padrão do Fifty, mas conta Stripe separada).

**No MVP Fase 0-1:** sem billing. Todas as contas são gratuitas até validar produto.

---

## Riscos conhecidos

| Risco | Probabilidade | Impacto | Mitigação |
|-------|--------------|---------|-----------|
| Apify quebra ou muda API | Média | Alto | Abstração `ScrapingProvider` permite trocar de provider sem mudar app |
| Meta melhora detecção e bloqueia scraping em massa | Alta | Alto | Estratégia de longo prazo: scraper próprio com proxies residenciais (Fase N) |
| Qualidade das sugestões IA é baixa | Média | Crítico | Fase beta com 10 usuários teste antes de abrir pagantes, ajuste iterativo de prompts |
| LGPD — dados de perfis públicos de terceiros | Média | Médio | Retenção curta (30 dias) de dados brutos do scraping, acesso apenas a insights agregados |
| Token Meta API expira (60 dias) | Alta | Médio | Alerta 7 dias antes + renovação automática via refresh token |
| Usuário não configura chaves API (BYOK) | Média | Alto | Onboarding obrigatório de chaves antes de liberar primeira análise |
| Playbook de baixa qualidade por prompts ruins | Média | Alto | Schema estruturado obrigatório no AnalyzeStep — lixo não entra no playbook |

---

**Última atualização:** pós-brainstorming de Playbooks + BYOK + múltiplos nichos. Nicho do produto ampliado de "imobiliário" para "criadores de conteúdo com foco imobiliário". BYOK adicionado como princípio central. Sistema de Playbooks múltiplos formalizado.
