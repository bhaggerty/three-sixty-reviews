module Admin
  class ReviewCyclesController < ApplicationController
    before_action :require_admin

    def index
      @cycles = ReviewCycleRepository.new.all
    end

    def new
    end

    def create
      cycle = ReviewCycleRepository.new.upsert(ReviewCycle.new(
        id: SecureRandom.uuid,
        name: params[:name],
        status: "draft",
        question_set_version: QuestionSet.current_version
      ))

      ::Reviews::CycleKickoffJob.perform_later(cycle.id)
      redirect_to admin_review_cycles_path, notice: "Cycle created; generating assignments."
    end

    private

    def require_admin
      render_forbidden unless current_user.admin?
    end
  end
end
