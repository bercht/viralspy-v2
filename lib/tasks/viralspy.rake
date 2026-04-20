# lib/tasks/viralspy.rake
namespace :viralspy do
  desc "Popula ApiCredential pra uma conta usando ENVs (dev-only). " \
       "Uso: ACCOUNT_ID=1 VALIDATE=true FORCE=true bin/rails viralspy:dev_setup_credentials"
  task dev_setup_credentials: :environment do
    if Rails.env.production?
      abort "❌ viralspy:dev_setup_credentials é dev-only. Em produção credenciais são BYOK via UI."
    end

    account = resolve_account
    unless account
      abort "❌ Nenhuma Account encontrada. Crie uma conta antes (ex: signup em /users/sign_up)."
    end

    puts "→ Populando credenciais pra Account##{account.id} (#{account.name})"

    env_to_provider = {
      "OPENAI_API_KEY"     => "openai",
      "ANTHROPIC_API_KEY"  => "anthropic",
      "ASSEMBLYAI_API_KEY" => "assemblyai"
    }

    force    = ENV["FORCE"] == "true"
    validate = ENV["VALIDATE"] == "true"

    ActsAsTenant.with_tenant(account) do
      env_to_provider.each do |env_name, provider|
        api_key = ENV[env_name].to_s.strip

        if api_key.empty?
          puts "  ⊘ #{provider.ljust(10)} — #{env_name} vazio ou ausente, pulando"
          next
        end

        credential = account.api_credentials.find_by(provider: provider)

        if credential && !force
          puts "  ⊘ #{provider.ljust(10)} — credential já existe, use FORCE=true pra sobrescrever"
          next
        end

        if credential
          credential.update!(encrypted_api_key: api_key, active: true, last_validation_status: :unknown, last_validated_at: nil)
          puts "  ↻ #{provider.ljust(10)} — credential sobrescrita"
        else
          credential = account.api_credentials.create!(
            provider: provider,
            encrypted_api_key: api_key,
            active: true
          )
          puts "  ✓ #{provider.ljust(10)} — credential criada"
        end

        if validate
          print "    → validando... "
          result = ApiCredentials::ValidateService.call(credential)
          if result.success?
            puts "✓ #{result.status}"
          else
            puts "✗ #{result.status} (#{result.message})"
          end
        end
      end
    end

    puts "\n✓ Pronto. Visite /settings/api_keys pra conferir na UI."
  end

  def resolve_account
    if ENV["ACCOUNT_ID"]
      Account.find_by(id: ENV["ACCOUNT_ID"])
    else
      Account.first
    end
  end
end
