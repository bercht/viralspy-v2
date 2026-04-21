namespace :playbooks do
  desc "Backfill de analises concluidas para um playbook. " \
       "Uso: bin/rails \"playbooks:backfill[PLAYBOOK_ID, ID1 ID2 ID3]\" " \
       "ou PLAYBOOK_ID=1 ANALYSIS_IDS=1,2,3 bin/rails playbooks:backfill"
  task :backfill, [ :playbook_id, :analysis_ids ] => :environment do |_task, args|
    playbook_id = resolve_playbook_id(args)
    analysis_ids = resolve_analysis_ids(args)

    playbook = Playbook.unscoped.find_by(id: playbook_id)
    abort "Playbook #{playbook_id} not found" unless playbook

    analyses = resolve_analyses!(analysis_ids)
    validate_same_account!(playbook: playbook, analyses: analyses)
    validate_completed!(analyses)

    previous_tenant = ActsAsTenant.current_tenant
    ActsAsTenant.current_tenant = playbook.account

    begin
      analyses.sort_by(&:created_at).each do |analysis|
        process_analysis!(playbook: playbook, analysis: analysis)
      end
    ensure
      ActsAsTenant.current_tenant = previous_tenant
    end
  end

  def resolve_playbook_id(args)
    raw = args[:playbook_id].presence || ENV["PLAYBOOK_ID"].presence
    abort missing_ids_usage_message if raw.blank?

    Integer(raw.to_s, 10)
  rescue ArgumentError, TypeError
    abort "Invalid playbook_id: #{raw.inspect}"
  end

  def resolve_analysis_ids(args)
    raw = args[:analysis_ids].presence || ENV["ANALYSIS_IDS"].presence
    abort missing_ids_usage_message if raw.blank?

    tokens = raw.to_s.split(/[,\s]+/).reject(&:blank?)
    abort missing_ids_usage_message if tokens.empty?

    tokens.map { |token| Integer(token, 10) }.uniq
  rescue ArgumentError
    abort "Invalid analysis_ids: #{raw.inspect}"
  end

  def resolve_analyses!(analysis_ids)
    analysis_ids.map do |analysis_id|
      analysis = Analysis.unscoped.find_by(id: analysis_id)
      abort "Analysis #{analysis_id} not found" unless analysis

      analysis
    end
  end

  def validate_same_account!(playbook:, analyses:)
    invalid_ids = analyses.reject { |analysis| analysis.account_id == playbook.account_id }.map(&:id)
    return if invalid_ids.empty?

    abort "Analyses #{invalid_ids.join(', ')} do not belong to Playbook #{playbook.id} account #{playbook.account_id}"
  end

  def validate_completed!(analyses)
    invalid = analyses.reject(&:completed?)
    return if invalid.empty?

    details = invalid.map { |analysis| "#{analysis.id}(#{analysis.status})" }.join(", ")
    abort "All analyses must be completed. Invalid analyses: #{details}"
  end

  def process_analysis!(playbook:, analysis:)
    analysis_playbook = AnalysisPlaybook.find_or_create_by!(analysis: analysis, playbook: playbook) do |record|
      record.update_status = :playbook_update_pending
    end

    if analysis_playbook.playbook_update_completed?
      puts "Analysis #{analysis.id}: already processed, skipping"
      return
    end

    if analysis_playbook.playbook_update_failed?
      analysis_playbook.playbook_update_pending!
      puts "Analysis #{analysis.id}: previous status failed, retrying"
    end

    puts "Analysis #{analysis.id}: starting playbook update"
    result = Analyses::UpdatePlaybookStep.call(analysis_playbook)

    if result.failure?
      puts "Analysis #{analysis.id}: failed (#{result.error_code || :unknown}) - #{result.error}"
      abort "Backfill aborted on Analysis #{analysis.id}"
    end

    puts "Analysis #{analysis.id}: completed"
  end

  def missing_ids_usage_message
    "playbook_id and analysis_ids are required. " \
      "Usage: bin/rails \"playbooks:backfill[PLAYBOOK_ID, ID1 ID2 ID3]\""
  end
end
