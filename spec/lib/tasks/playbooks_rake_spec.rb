require "rails_helper"
require "rake"

RSpec.describe "playbooks:backfill" do
  let(:task_name) { "playbooks:backfill" }
  let(:task) { Rake::Task[task_name] }
  let(:success_result) { Analyses::Result.success(data: { version_number: 1 }) }

  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("playbooks:backfill")
  end

  after do
    task.reenable
    ENV.delete("PLAYBOOK_ID")
    ENV.delete("ANALYSIS_IDS")
    ActsAsTenant.current_tenant = nil
  end

  it "cria analysis_playbooks e processa em ordem cronologica ascendente" do
    account = create(:account)
    playbook = create(:playbook, account: account)
    analysis_oldest = create(:analysis, :completed, account: account, created_at: 3.days.ago)
    analysis_middle = create(:analysis, :completed, account: account, created_at: 2.days.ago)
    analysis_newest = create(:analysis, :completed, account: account, created_at: 1.day.ago)
    processed_ids = []

    allow(Analyses::UpdatePlaybookStep).to receive(:call) do |analysis_playbook|
      processed_ids << analysis_playbook.analysis_id
      analysis_playbook.playbook_update_completed!
      success_result
    end

    invoke_task(playbook_id: playbook.id, analysis_ids: "#{analysis_newest.id} #{analysis_oldest.id} #{analysis_middle.id}")

    expect(processed_ids).to eq([ analysis_oldest.id, analysis_middle.id, analysis_newest.id ])
    expect(AnalysisPlaybook.where(playbook: playbook).count).to eq(3)
  end

  it "e idempotente para analysis_playbooks ja processados" do
    account = create(:account)
    playbook = create(:playbook, account: account)
    analysis_one = create(:analysis, :completed, account: account, created_at: 2.days.ago)
    analysis_two = create(:analysis, :completed, account: account, created_at: 1.day.ago)
    create(:playbook_version, account: account, playbook: playbook, version_number: 1)
    create(:analysis_playbook, analysis: analysis_one, playbook: playbook, update_status: :playbook_update_completed)
    create(:analysis_playbook, analysis: analysis_two, playbook: playbook, update_status: :playbook_update_completed)

    allow(Analyses::UpdatePlaybookStep).to receive(:call).and_return(success_result)

    2.times do
      invoke_task(playbook_id: playbook.id, analysis_ids: "#{analysis_one.id} #{analysis_two.id}")
    end

    expect(AnalysisPlaybook.where(playbook: playbook).count).to eq(2)
    expect(Analyses::UpdatePlaybookStep).not_to have_received(:call)
    expect(PlaybookVersion.where(playbook: playbook).count).to eq(1)
  end

  it "aborta quando o playbook nao existe" do
    expect do
      invoke_task(playbook_id: 999_999, analysis_ids: "1")
    end.to raise_error(SystemExit, /Playbook 999999 not found/)
  end

  it "aborta quando a analise pertence a outra account" do
    playbook_account = create(:account)
    other_account = create(:account)
    playbook = create(:playbook, account: playbook_account)
    analysis = create(:analysis, :completed, account: other_account)

    expect do
      invoke_task(playbook_id: playbook.id, analysis_ids: analysis.id.to_s)
    end.to raise_error(SystemExit, /do not belong to Playbook #{playbook.id} account #{playbook.account_id}/)
  end

  it "aborta quando ha analise com status diferente de completed" do
    account = create(:account)
    playbook = create(:playbook, account: account)
    failed_analysis = create(:analysis, :failed, account: account)

    expect do
      invoke_task(playbook_id: playbook.id, analysis_ids: failed_analysis.id.to_s)
    end.to raise_error(SystemExit, /All analyses must be completed\. Invalid analyses: #{failed_analysis.id}\(failed\)/)
  end

  it "reprocessa analysis_playbook com status failed" do
    account = create(:account)
    playbook = create(:playbook, account: account)
    analysis = create(:analysis, :completed, account: account)
    analysis_playbook = create(
      :analysis_playbook,
      analysis: analysis,
      playbook: playbook,
      update_status: :playbook_update_failed
    )
    statuses_seen = []

    allow(Analyses::UpdatePlaybookStep).to receive(:call) do |ap|
      statuses_seen << ap.update_status
      ap.playbook_update_completed!
      success_result
    end

    invoke_task(playbook_id: playbook.id, analysis_ids: analysis.id.to_s)

    expect(statuses_seen).to eq([ "playbook_update_pending" ])
    expect(analysis_playbook.reload).to be_playbook_update_completed
  end

  it "aborta na primeira falha do update e nao processa as proximas analises" do
    account = create(:account)
    playbook = create(:playbook, account: account)
    first_analysis = create(:analysis, :completed, account: account, created_at: 2.days.ago)
    second_analysis = create(:analysis, :completed, account: account, created_at: 1.day.ago)
    processed_ids = []

    allow(Analyses::UpdatePlaybookStep).to receive(:call) do |analysis_playbook|
      processed_ids << analysis_playbook.analysis_id

      if analysis_playbook.analysis_id == first_analysis.id
        Analyses::Result.failure(error: "llm indisponivel", error_code: :llm_failed)
      else
        success_result
      end
    end

    expect do
      invoke_task(playbook_id: playbook.id, analysis_ids: "#{second_analysis.id} #{first_analysis.id}")
    end.to raise_error(SystemExit, /Backfill aborted on Analysis #{first_analysis.id}/)

    expect(processed_ids).to eq([ first_analysis.id ])
  end

  def invoke_task(playbook_id:, analysis_ids:)
    task.reenable
    task.invoke(playbook_id, analysis_ids)
  end
end
