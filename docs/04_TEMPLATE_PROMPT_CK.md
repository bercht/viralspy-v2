# 04_TEMPLATE_PROMPT_CK — Template para Prompts do Claude Code

> Use este template toda vez que gerar um prompt para CK. Preencha todas as seções. Prompts CK são auto-contidos — CK não tem contexto externo ao prompt.

---

## Estrutura do template

```markdown
# [TÍTULO DA FASE/FEATURE] — Claude Code Prompt

> **Contexto rápido:** 1-2 parágrafos explicando onde essa fase se encaixa no produto.

---

## 🎯 OBJETIVO

[O que essa fase entrega, em 1-3 frases. Foco no outcome, não nas tarefas.]

---

## 📋 PRÉ-REQUISITOS

Antes de começar, garantir que:

- [ ] Fase [X] anterior está mergeada em `main`
- [ ] `docker compose up` está rodando sem erros
- [ ] Variáveis de ambiente necessárias estão definidas (listar quais)
- [ ] Gems necessárias estão instaladas

---

## 🧱 CONTEXTO TÉCNICO

### Stack e padrões

- **Ruby 3.3.x + Rails 7.1.x**
- **Tailwind CSS (apenas utility classes — sem @apply, sem CSS custom)**
- **Hotwire (Turbo + Stimulus)** para comportamento interativo
- **RSpec + FactoryBot + WebMock + VCR** para testes
- Multi-tenancy via `acts_as_tenant`

### Regras rígidas (NÃO violar)

- Zero CSS customizado, zero `<style>` tags, zero `style="..."` inline
- Zero classes CSS criadas — só utility classes Tailwind
- JavaScript SOMENTE em Stimulus controllers (sem jQuery, sem `<script>` inline)
- Nenhuma chamada real a API externa em testes (usar VCR/WebMock)

### Arquivos/módulos já existentes que serão usados

[Listar o que já existe e deve ser importado/referenciado]

---

## 🔨 TAREFAS

Execute em ordem. Cada tarefa maior termina com um commit pequeno mas testável.

### Tarefa 1: [Nome curto]

**O quê:** [descrição em 1 linha]

**Como:**

1. [Passo 1]
2. [Passo 2]
3. [Passo 3]

**Código de referência:**

```ruby
# caminho/arquivo.rb
[exemplo de código]
```

**Testes a criar:**

- [Teste 1]
- [Teste 2]

### Tarefa 2: [...]

[repetir]

---

## 🧪 TESTES

Cobertura mínima obrigatória:

- [ ] Model specs: validations, associations, scopes
- [ ] Service specs: comportamento + edge cases
- [ ] Worker specs (se aplicável)
- [ ] Request specs (se aplicável)

### Exemplo de teste com VCR

```ruby
# [se fizer chamadas HTTP externas]
```

### Exemplo de teste com WebMock

```ruby
# [se preferir mocking simples]
```

---

## ✅ CRITÉRIO DE ACEITE

A fase está completa SOMENTE quando TODOS os critérios abaixo são atingidos:

- [ ] [Critério mensurável 1 — ex: "Usuário consegue adicionar competitor via UI"]
- [ ] [Critério 2]
- [ ] Todos testes passam (`bin/rspec`)
- [ ] Rubocop passa sem warnings (`bin/rubocop`)
- [ ] ERB Lint passa (`bin/erb_lint --lint-all`)
- [ ] Zero CSS custom, zero classes criadas
- [ ] Todas interações JS via Stimulus
- [ ] Migrations rodadas em dev (`bin/rails db:migrate`)

---

## 📝 COMMIT MESSAGE SUGERIDA

```
feat(fase-X): [descrição breve da feature]

- [bullet do que foi feito]
- [outro bullet]
- [outro]

Closes #[issue-number-se-houver]
```

---

## ⚠️ ALERTAS E PONTOS DE ATENÇÃO

[Coisas que podem dar errado, edge cases conhecidos, decisões tomadas durante o prompt que vale explicitar]

---

## 💬 SE FICAR EM DÚVIDA

Pergunte ao Curt antes de assumir:

- [Pergunta-exemplo 1]
- [Pergunta-exemplo 2]

NÃO invente comportamento. NÃO mude stack. NÃO crie arquivos fora do escopo.
```

---

## Diretrizes para GERAR prompts usando este template

Quando o Curt pedir "gera prompt CK para [fase/feature]":

### 1. Leia o documento de fase primeiro

Consulte `03_ROADMAP_FASES.md` na seção da fase pedida. Extraia: objetivo, escopo, critério de aceite.

### 2. Seja verboso, não conciso

CK trabalha melhor com muito contexto do que pouco. Prompts CK bons têm 500-1500 linhas. Não corte detalhes para "ficar elegante".

### 3. Inclua código de referência completo

Se a fase envolve criar um service, inclua o código completo do service no prompt. Não escreva "crie um ScrapingProvider" — escreva a classe toda, mesmo que CK vá recriar.

### 4. Seja explícito sobre o que NÃO fazer

Ao final, sempre liste "NÃO FAÇA:" com itens específicos. Exemplos:
- NÃO crie billing ainda
- NÃO adicione gem X
- NÃO use webpack

### 5. Estrutura de tarefas numerada e atômica

Cada tarefa maior termina em um commit. Se uma tarefa é grande demais para um commit, quebre em subtarefas.

### 6. Testes como parte do prompt, não como adendo

Para cada tarefa, liste os testes que DEVEM ser criados. Testes não são opcionais.

### 7. Critério de aceite mensurável

Não: "UI deve estar bonita"
Sim: "Usuário consegue clicar em 'Nova análise' e ser redirecionado para a página de detalhe com status 'pending'"

### 8. Termine com comunicação ao dev humano

Seção "💬 SE FICAR EM DÚVIDA" com perguntas que CK deve fazer ao Curt antes de assumir.

---

## Exemplos de prompts bem construídos

### Bom prompt tem:

- ✅ Título descritivo
- ✅ Contexto de onde se encaixa no produto
- ✅ Pré-requisitos verificáveis
- ✅ Regras rígidas repetidas (Tailwind puro, Stimulus, etc)
- ✅ Tarefas numeradas com código de referência
- ✅ Testes específicos por tarefa
- ✅ Critério de aceite mensurável
- ✅ Commit message sugerida
- ✅ Lista "NÃO FAÇA"

### Prompt ruim tem:

- ❌ "Implemente o scraping" (vago)
- ❌ "Use boas práticas" (genérico)
- ❌ Sem critério de aceite mensurável
- ❌ Omissão de testes
- ❌ Não lembra CK das regras rígidas de frontend
- ❌ Assume contexto que CK não tem

---

## Casos especiais

### Prompt para refactor (não feature nova)

Adicionar seção "🔄 COMPORTAMENTO ANTES vs DEPOIS":

```markdown
## 🔄 COMPORTAMENTO ANTES vs DEPOIS

**Antes:** [comportamento atual]
**Depois:** [comportamento esperado]

**Testes que devem continuar verdes:** [listar]
```

### Prompt para bugfix

Adicionar seção "🐛 BUG A CORRIGIR":

```markdown
## 🐛 BUG A CORRIGIR

**Sintoma:** [o que acontece]
**Causa raiz identificada:** [análise]
**Reprodução:** [passos]
**Fix:** [o que fazer]
**Teste de regressão:** [o teste que PROVA que o fix funciona]
```

### Prompt para integração externa

Adicionar seção "🔌 EXTERNAL API":

```markdown
## 🔌 API EXTERNA

**Provider:** [nome]
**Docs:** [link]
**Endpoint:** [URL]
**Auth:** [como autenticar]
**Rate limits:** [limites]
**Exemplo de response:** [JSON exemplo]
**Estratégia de mock em testes:** [VCR / WebMock]
```

---

**Fim do template.**
