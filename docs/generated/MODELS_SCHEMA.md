# Models Schema

Esquema completo dos models de domínio. Extraído de `db/schema.rb` e dos próprios models. Gerado automaticamente — não edite à mão.

---

## Account

**Table:** `accounts`
**Tenant-scoped:** não (é a raiz do tenant)

### Columns
| Nome | Tipo | Default | Null | Notas |
|------|------|---------|------|-------|
| id | bigint | — | not null | PK |
| name | string | — | not null | |
| llm_preferences | jsonb | `{}` | — | Preferências de provider/modelo LLM por grupo |
| media_generation_preferences | jsonb | `{}` | — | Preferências HeyGen (avatar_id, voice_id) |
| created_at | datetime | — | not null | |
| updated_at | datetime | — | not null | |

### Enums
(nenhum)

### Associations
- has_many :users (dependent: :destroy)
- has_many :competitors (dependent: :destroy)
- has_many :analyses (dependent: :destroy)
- has_many :posts (dependent: :destroy)
- has_many :content_suggestions (dependent: :destroy)
- has_many :llm_usage_logs (dependent: :nullify)
- has_many :transcription_usage_logs (dependent: :nullify)
- has_many :api_credentials (dependent: :destroy)
- has_many :playbooks (dependent: :destroy)
- has_many :playbook_feedbacks (dependent: :destroy)
- has_many :playbook_suggestions (dependent: :destroy)
- has_many :generated_medias (dependent: :destroy)
- has_many :media_generation_usage_logs (dependent: :destroy)

### Validations
- validates :name, presence: true

### Scopes principais
(nenhum definido)

### Métodos públicos
- `llm_preferences_with_defaults` → Hash com defaults para grupos transcription/analysis/generation
- `api_credential_for(provider)` → ApiCredential ou nil
- `ready_for_analysis?` → Boolean
- `missing_credentials_for_analysis` → Array de símbolos

---

## User

**Table:** `users`
**Tenant-scoped:** não (`belongs_to :account`, mas sem `acts_as_tenant`)

### Columns
| Nome | Tipo | Default | Null | Notas |
|------|------|---------|------|-------|
| id | bigint | — | not null | PK |
| email | string | — | not null | unique |
| encrypted_password | string | — | not null | Devise |
| reset_password_token | string | — | — | unique |
| reset_password_sent_at | datetime | — | — | |
| remember_created_at | datetime | — | — | |
| first_name | string | — | — | |
| last_name | string | — | — | |
| account_id | bigint | — | not null | FK → accounts |
| created_at | datetime | — | not null | |
| updated_at | datetime | — | not null | |

**Índices:** account_id, email (unique), reset_password_token (unique)

### Enums
(nenhum)

### Associations
- belongs_to :account

### Validations
- validates :first_name, presence: true
- validates :last_name, presence: true
- Devise: validatable (email + password)

### Módulos Devise
database_authenticatable, registerable, recoverable, rememberable, validatable

### Métodos públicos
- `full_name` → String

---

## ApiCredential

**Table:** `api_credentials`
**Tenant-scoped:** sim (`acts_as_tenant :account`)

### Columns
| Nome | Tipo | Default | Null | Notas |
|------|------|---------|------|-------|
| id | bigint | — | not null | PK |
| account_id | bigint | — | not null | FK → accounts |
| provider | string | — | not null | enum string |
| encrypted_api_key | string | — | not null | armazenada encriptada |
| active | boolean | `true` | not null | |
| last_validated_at | datetime | — | — | |
| last_validation_status | integer | `0` | not null | enum inteiro |
| created_at | datetime | — | not null | |
| updated_at | datetime | — | not null | |

**Índices:** account_id + provider (unique), account_id

### Enums
- `provider`: `{ openai: "openai", anthropic: "anthropic", assemblyai: "assemblyai", heygen: "heygen" }` (prefix: :provider)
- `last_validation_status`: `{ unknown: 0, verified: 1, failed: 2, quota_exceeded: 3 }` (prefix: :validation)

### Associations
- belongs_to :account

### Validations
- validates :provider, presence: true, inclusion in PROVIDERS
- validates :encrypted_api_key, presence: true
- validates :account_id, uniqueness: { scope: :provider }

### Scopes principais
- `active` → where(active: true)

### Métodos públicos
- `api_key` → retorna encrypted_api_key (getter)
- `api_key=(value)` → setter que encripta

### Constantes
- `PROVIDERS = ["openai", "anthropic", "assemblyai", "heygen"]`

---

## Competitor

**Table:** `competitors`
**Tenant-scoped:** sim (`acts_as_tenant :account`)

### Columns
| Nome | Tipo | Default | Null | Notas |
|------|------|---------|------|-------|
| id | bigint | — | not null | PK |
| account_id | bigint | — | not null | FK → accounts |
| instagram_handle | string | — | not null | sem @, lowercase |
| full_name | string | — | — | |
| bio | text | — | — | |
| followers_count | integer | — | — | |
| following_count | integer | — | — | |
| posts_count | integer | — | — | |
| profile_pic_url | string | — | — | |
| last_scraped_at | datetime | — | — | |
| created_at | datetime | — | not null | |
| updated_at | datetime | — | not null | |

**Índices:** account_id + instagram_handle (unique, case-insensitive), account_id

### Enums
(nenhum)

### Associations
- belongs_to :account
- has_many :analyses (dependent: :destroy)

### Validations
- validates :instagram_handle, presence: true, format: `/\A[a-zA-Z0-9_.]{1,30}\z/`, uniqueness: { scope: :account_id, case_sensitive: false }
- before_validation: `normalize_handle` (strip, lowercase, remove @)

### Scopes principais
- `recent` → order(created_at: :desc)

---

## Analysis

**Table:** `analyses`
**Tenant-scoped:** sim (`acts_as_tenant :account`)

### Columns
| Nome | Tipo | Default | Null | Notas |
|------|------|---------|------|-------|
| id | bigint | — | not null | PK |
| account_id | bigint | — | not null | FK → accounts |
| competitor_id | bigint | — | not null | FK → competitors |
| status | integer | `0` | not null | enum |
| scraping_provider | string | — | — | |
| scraping_run_id | string | — | — | |
| raw_data | jsonb | `{}` | — | |
| profile_metrics | jsonb | `{}` | — | resultado do ProfileMetricsStep |
| insights | jsonb | `{}` | — | resultado do AnalyzeStep |
| posts_scraped_count | integer | `0` | — | |
| posts_analyzed_count | integer | `0` | — | |
| error_message | text | — | — | |
| started_at | datetime | — | — | |
| finished_at | datetime | — | — | |
| max_posts | integer | `50` | not null | range [10, 100] |
| created_at | datetime | — | not null | |
| updated_at | datetime | — | not null | |

**Índices:** account_id + created_at, account_id, competitor_id, status

### Enums
- `status`: `{ pending: 0, scraping: 1, scoring: 2, transcribing: 3, analyzing: 4, generating_suggestions: 5, completed: 7, failed: 8 }`
  - **ATENÇÃO:** índice 6 reservado (removido em Fase 1.5b — NÃO REUSAR sem verificar dados de produção)

### Associations
- belongs_to :account
- belongs_to :competitor
- has_many :posts (dependent: :destroy)
- has_many :content_suggestions (dependent: :destroy)
- has_many :analysis_playbooks (dependent: :destroy)
- has_many :playbooks (through: :analysis_playbooks)
- has_many :llm_usage_logs (dependent: :nullify)
- has_many :transcription_usage_logs (dependent: :nullify)

### Validations
- validates :max_posts, numericality: { only_integer: true, greater_than_or_equal_to: 10, less_than_or_equal_to: 100 }

### Scopes principais
- `recent` → order(created_at: :desc)
- `in_progress` → where(status: [:pending, :scraping, :scoring, :transcribing, :analyzing, :generating_suggestions])

### Callbacks
- after_update_commit: `broadcast_status_change` (se status mudou) — Turbo Streams

### Métodos públicos
- `duration_seconds` → Integer ou nil

---

## Post

**Table:** `posts`
**Tenant-scoped:** sim (`acts_as_tenant :account`)

### Columns
| Nome | Tipo | Default | Null | Notas |
|------|------|---------|------|-------|
| id | bigint | — | not null | PK |
| analysis_id | bigint | — | not null | FK → analyses |
| competitor_id | bigint | — | not null | FK → competitors |
| account_id | bigint | — | not null | FK → accounts |
| instagram_post_id | string | — | not null | |
| shortcode | string | — | — | |
| post_type | integer | — | not null | enum |
| caption | text | — | — | |
| display_url | string | — | — | |
| video_url | string | — | — | |
| likes_count | integer | `0` | not null | |
| comments_count | integer | `0` | not null | |
| video_view_count | integer | — | — | |
| hashtags | string[] | `[]` | — | array PostgreSQL |
| mentions | string[] | `[]` | — | array PostgreSQL |
| posted_at | datetime | — | — | |
| quality_score | decimal(10,4) | — | — | calculado por Scoring::Formula |
| selected_for_analysis | boolean | `false` | not null | |
| transcript | text | — | — | |
| transcript_status | integer | `0` | — | enum |
| transcribed_at | datetime | — | — | |
| created_at | datetime | — | not null | |
| updated_at | datetime | — | not null | |

**Índices:** account_id + posted_at, analysis_id + post_type + quality_score, analysis_id + selected_for_analysis, analysis_id, competitor_id, instagram_post_id

### Enums
- `post_type`: `{ reel: 0, carousel: 1, image: 2 }`
- `transcript_status`: `{ pending: 0, completed: 1, failed: 2, skipped: 3 }` (prefix: :transcript)

### Associations
- belongs_to :account
- belongs_to :analysis
- belongs_to :competitor

### Validations
- validates :instagram_post_id, presence: true
- validates :post_type, presence: true

### Scopes principais
- `selected` → where(selected_for_analysis: true)
- `by_type(type)` → where(post_type: type)
- `ranked` → order(quality_score: :desc)
- `recent_first` → order(posted_at: :desc)
- `eligible_for_scoring` → likes + comments >= 10, posted_at presente e > 6h atrás

### Métodos públicos
- `has_video?` → Boolean

---

## ContentSuggestion

**Table:** `content_suggestions`
**Tenant-scoped:** sim (`acts_as_tenant :account`)

### Columns
| Nome | Tipo | Default | Null | Notas |
|------|------|---------|------|-------|
| id | bigint | — | not null | PK |
| analysis_id | bigint | — | not null | FK → analyses |
| account_id | bigint | — | not null | FK → accounts |
| position | integer | — | not null | unique por analysis |
| content_type | integer | — | not null | enum |
| hook | string | — | — | |
| caption_draft | text | — | — | |
| format_details | jsonb | `{}` | — | estrutura varia por tipo |
| suggested_hashtags | string[] | `[]` | — | array PostgreSQL |
| rationale | text | — | — | |
| status | integer | `0` | — | enum |
| created_at | datetime | — | not null | |
| updated_at | datetime | — | not null | |

**Índices:** account_id + created_at, analysis_id + content_type, analysis_id + position (unique), analysis_id, account_id

### Enums
- `content_type`: `{ reel: 0, carousel: 1, image: 2 }` (prefix: :content)
- `status`: `{ draft: 0, saved: 1, discarded: 2 }`

### Associations
- belongs_to :account
- belongs_to :analysis
- has_many :generated_medias (dependent: :destroy)

### Validations
- validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, uniqueness: { scope: :analysis_id }
- validates :content_type, presence: true

### Scopes principais
- `ordered` → order(position: :asc)
- `by_content_type(type)` → where(content_type: type)

---

## GeneratedMedia

**Table:** `generated_medias`
**Tenant-scoped:** sim (`acts_as_tenant :account`)

### Columns
| Nome | Tipo | Default | Null | Notas |
|------|------|---------|------|-------|
| id | bigint | — | not null | PK |
| account_id | bigint | — | not null | FK → accounts |
| content_suggestion_id | bigint | — | not null | FK → content_suggestions |
| provider | string | `"heygen"` | not null | enum string |
| media_type | integer | `0` | — | enum |
| status | integer | `0` | — | enum |
| prompt_sent | text | — | — | script enviado para HeyGen |
| provider_params | jsonb | `{}` | — | avatar_id, voice_id |
| provider_job_id | string | — | — | ID do job HeyGen |
| output_url | string | — | — | URL do vídeo gerado |
| duration_seconds | integer | — | — | |
| cost_cents | integer | — | — | em centavos BRL |
| error_message | text | — | — | |
| started_at | datetime | — | — | |
| finished_at | datetime | — | — | |
| created_at | datetime | — | not null | |
| updated_at | datetime | — | not null | |

**Índices:** account_id + created_at, content_suggestion_id, provider_job_id, status

### Enums
- `status`: `{ pending: 0, processing: 1, completed: 2, failed: 3 }`
- `media_type`: `{ avatar_video: 0 }`
- `provider`: `{ heygen: "heygen" }` (prefix: :provider)

### Associations
- belongs_to :account
- belongs_to :content_suggestion
- has_many :media_generation_usage_logs (dependent: :destroy)

### Validations
- validates :provider, presence: true
- validates :media_type, presence: true
- validates :status, presence: true

### Scopes principais
- `recent` → order(created_at: :desc)
- `for_suggestion(suggestion)` → where(content_suggestion: suggestion)

---

## LLMUsageLog

**Table:** `llm_usage_logs`
**Tenant-scoped:** sim (`acts_as_tenant :account`)

### Columns
| Nome | Tipo | Default | Null | Notas |
|------|------|---------|------|-------|
| id | bigint | — | not null | PK |
| account_id | bigint | — | not null | FK → accounts |
| analysis_id | bigint | — | — | FK → analyses (optional) |
| provider | string | — | not null | |
| model | string | — | not null | |
| use_case | string | — | — | ex: reel_analysis, content_suggestions |
| prompt_tokens | integer | — | — | |
| completion_tokens | integer | — | — | |
| cost_cents | integer | — | — | em centavos BRL |
| created_at | datetime | — | not null | |
| updated_at | datetime | — | not null | |

**Índices:** account_id + created_at, account_id, analysis_id

### Enums
(nenhum)

### Associations
- belongs_to :account
- belongs_to :analysis (optional)

### Validations
- validates :provider, presence: true
- validates :model, presence: true

### Scopes principais
- `recent` → order(created_at: :desc)
- `by_use_case(uc)` → where(use_case: uc)

---

## TranscriptionUsageLog

**Table:** `transcription_usage_logs`
**Tenant-scoped:** sim (`acts_as_tenant :account`)

### Columns
| Nome | Tipo | Default | Null | Notas |
|------|------|---------|------|-------|
| id | bigint | — | not null | PK |
| account_id | bigint | — | not null | FK → accounts |
| post_id | bigint | — | — | FK → posts (optional) |
| analysis_id | bigint | — | — | FK → analyses (optional) |
| provider | string | — | not null | |
| model | string | — | not null | |
| audio_duration_seconds | integer | — | — | |
| cost_cents | integer | — | — | em centavos BRL |
| created_at | datetime | — | not null | |
| updated_at | datetime | — | not null | |

**Índices:** account_id + created_at, account_id, analysis_id, post_id

### Enums
(nenhum)

### Associations
- belongs_to :account
- belongs_to :analysis (optional)
- belongs_to :post (optional)

### Validations
- validates :provider, presence: true
- validates :model, presence: true

### Scopes principais
- `recent` → order(created_at: :desc)

---

## MediaGenerationUsageLog

**Table:** `media_generation_usage_logs`
**Tenant-scoped:** sim (`acts_as_tenant :account`)

### Columns
| Nome | Tipo | Default | Null | Notas |
|------|------|---------|------|-------|
| id | bigint | — | not null | PK |
| account_id | bigint | — | not null | FK → accounts |
| generated_media_id | bigint | — | not null | FK → generated_medias |
| provider | string | — | not null | |
| duration_seconds | integer | — | — | |
| cost_cents | integer | — | — | em centavos BRL |
| created_at | datetime | — | not null | |
| updated_at | datetime | — | not null | |

**Índices:** account_id + created_at, generated_media_id

### Enums
(nenhum)

### Associations
- belongs_to :account
- belongs_to :generated_media

### Validations
- validates :provider, presence: true

---

## Playbook

**Table:** `playbooks`
**Tenant-scoped:** sim (`acts_as_tenant :account`)

### Columns
| Nome | Tipo | Default | Null | Notas |
|------|------|---------|------|-------|
| id | bigint | — | not null | PK |
| account_id | bigint | — | not null | FK → accounts |
| name | string | — | not null | unique por account |
| niche | string | — | — | |
| purpose | text | — | — | |
| current_version_number | integer | `0` | not null | 0 = sem versão ainda |
| created_at | datetime | — | not null | |
| updated_at | datetime | — | not null | |

**Índices:** account_id + name (unique), account_id

### Enums
(nenhum)

### Associations
- belongs_to :account
- has_many :playbook_versions (dependent: :destroy)
- has_many :playbook_feedbacks (dependent: :destroy)
- has_many :analysis_playbooks (dependent: :destroy)
- has_many :analyses (through: :analysis_playbooks)
- has_many :playbook_suggestions (dependent: :destroy)

### Validations
- validates :name, presence: true, uniqueness: { scope: :account_id, case_sensitive: false }

### Scopes principais
- `recent` → order(created_at: :desc)

### Métodos públicos
- `current_version` → PlaybookVersion ou nil
- `current_content` → String (markdown da versão atual)
- `initial_content` → String (template markdown inicial)

---

## PlaybookVersion

**Table:** `playbook_versions`
**Tenant-scoped:** sim (`acts_as_tenant :account`)

### Columns
| Nome | Tipo | Default | Null | Notas |
|------|------|---------|------|-------|
| id | bigint | — | not null | PK |
| account_id | bigint | — | not null | FK → accounts |
| playbook_id | bigint | — | not null | FK → playbooks |
| version_number | integer | — | not null | unique por playbook |
| content | text | — | not null | markdown completo do playbook |
| diff_summary | text | — | — | resumo das mudanças (1-3 frases) |
| triggered_by_analysis_id | bigint | — | — | FK → analyses (optional) |
| incorporated_in_version_id | bigint | — | — | FK → playbook_versions (self-ref, optional) |
| feedbacks_incorporated_count | integer | `0` | — | |
| created_at | datetime | — | not null | |
| updated_at | datetime | — | not null | |

**Índices:** account_id, playbook_id + version_number (unique), playbook_id, triggered_by_analysis_id

### Enums
(nenhum)

### Associations
- belongs_to :account
- belongs_to :playbook
- belongs_to :triggered_by_analysis (class: "Analysis", FK: triggered_by_analysis_id, optional)

### Validations
- validates :content, presence: true
- validates :version_number, presence: true, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :playbook_id }

### Scopes principais
- `recent` → order(version_number: :desc)

---

## PlaybookFeedback

**Table:** `playbook_feedbacks`
**Tenant-scoped:** sim (`acts_as_tenant :account`)

### Columns
| Nome | Tipo | Default | Null | Notas |
|------|------|---------|------|-------|
| id | bigint | — | not null | PK |
| account_id | bigint | — | not null | FK → accounts |
| playbook_id | bigint | — | not null | FK → playbooks |
| content | text | — | not null | |
| source | string | — | not null | enum string (manual/auto) |
| status | integer | `0` | — | enum |
| incorporated_in_version_id | bigint | — | — | FK → playbook_versions (optional) |
| related_analysis_id | bigint | — | — | FK → analyses (optional) |
| related_own_post_id | integer | — | — | |
| created_at | datetime | — | not null | |
| updated_at | datetime | — | not null | |

**Índices:** account_id, playbook_id + status, playbook_id, incorporated_in_version_id

### Enums
- `status`: `{ pending: 0, incorporated: 1, dismissed: 2 }` (prefix: :status)
- `source`: `{ manual: 0, auto: 1 }` (prefix: :source)

### Associations
- belongs_to :account
- belongs_to :playbook

### Validations
- validates :content, presence: true

### Scopes principais
- `status_pending_scope` → where(status: :pending)
- `pending_for_playbook(playbook)` → where(playbook: playbook, status: :pending)

---

## PlaybookSuggestion

**Table:** `playbook_suggestions`
**Tenant-scoped:** sim (`acts_as_tenant :account`)

### Columns
| Nome | Tipo | Default | Null | Notas |
|------|------|---------|------|-------|
| id | bigint | — | not null | PK |
| account_id | bigint | — | not null | FK → accounts |
| playbook_id | bigint | — | not null | FK → playbooks |
| content_type | string | — | not null | enum string |
| hook | string | — | — | |
| caption_draft | text | — | — | |
| format_details | jsonb | `{}` | — | |
| suggested_hashtags | string[] | `[]` | — | array PostgreSQL |
| rationale | text | — | — | |
| status | integer | `0` | — | enum |
| created_at | datetime | — | not null | |
| updated_at | datetime | — | not null | |

**Índices:** account_id + created_at, playbook_id + status, playbook_id, account_id

### Enums
- `status`: `{ draft: 0, saved: 1, discarded: 2 }`
- `content_type`: `{ reel: "reel", carousel: "carousel", image: "image", story: "story" }` (string enum)

### Associations
- belongs_to :account
- belongs_to :playbook

### Validations
- validates :content_type, presence: true
- validates :status, presence: true

### Scopes principais
- `recent` → order(created_at: :desc)
- `visible` → where(status: [:draft, :saved])

---

## AnalysisPlaybook

**Table:** `analysis_playbooks`
**Tenant-scoped:** não (join table entre Analysis e Playbook)

### Columns
| Nome | Tipo | Default | Null | Notas |
|------|------|---------|------|-------|
| id | bigint | — | not null | PK |
| analysis_id | bigint | — | not null | FK → analyses |
| playbook_id | bigint | — | not null | FK → playbooks |
| update_status | integer | `0` | — | enum |
| created_at | datetime | — | not null | |
| updated_at | datetime | — | not null | |

**Índices:** analysis_id + playbook_id (unique), analysis_id, playbook_id

### Enums
- `update_status`: `{ playbook_update_pending: 0, playbook_update_completed: 1, playbook_update_failed: 2 }`

### Associations
- belongs_to :analysis
- belongs_to :playbook

### Validations
- validates :playbook_id, uniqueness: { scope: :analysis_id }

### Scopes principais
- `playbook_update_pending` → where(update_status: :playbook_update_pending)
