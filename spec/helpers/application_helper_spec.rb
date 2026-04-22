require "rails_helper"
require "ostruct"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#analysis_step_state" do
    it "retorna done quando o status atual já passou do step" do
      expect(helper.analysis_step_state(:scoring, :transcribing)).to eq(:done)
    end

    it "retorna active quando o status atual é o step" do
      expect(helper.analysis_step_state(:analyzing, :analyzing)).to eq(:active)
    end

    it "retorna pending quando o status atual ainda não chegou no step" do
      expect(helper.analysis_step_state(:completed, :scoring)).to eq(:pending)
    end
  end

  describe "#analysis_failed_step_status" do
    it "usa status anterior quando disponível" do
      analysis = OpenStruct.new(status_before_last_save: "analyzing", error_message: "qualquer erro")

      expect(helper.analysis_failed_step_status(analysis)).to eq(:analyzing)
    end

    it "infere o step pelo error_message quando não há status anterior" do
      analysis = OpenStruct.new(status_before_last_save: nil, error_message: "TranscribeStep crashed: timeout")

      expect(helper.analysis_failed_step_status(analysis)).to eq(:transcribing)
    end

    it "usa fallback em generating_suggestions quando não consegue inferir" do
      analysis = OpenStruct.new(status_before_last_save: nil, error_message: "Worker crashed: unknown")

      expect(helper.analysis_failed_step_status(analysis)).to eq(:generating_suggestions)
    end
  end
end
