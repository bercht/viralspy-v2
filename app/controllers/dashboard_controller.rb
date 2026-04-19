class DashboardController < ApplicationController
  def index
    # TODO(pos-mvp): adicionar análise do próprio perfil do usuário
    # (views, seguidores, engajamento) — ver 03_ROADMAP_FASES.md Fase 2+
    @competitors = current_account.competitors
                                  .includes(:analyses)
                                  .order(created_at: :desc)
                                  .limit(5)

    @recent_analyses = current_account.analyses
                                      .includes(:competitor)
                                      .order(created_at: :desc)
                                      .limit(5)
  end
end
