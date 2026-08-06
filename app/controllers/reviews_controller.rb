class ReviewsController < ApplicationController
  before_action :set_assignment, only: [ :show, :create, :update ]

  def index
    @to_review = ReviewAssignmentRepository.new.to_review_by(current_user.id)
    @about_me = ReviewAssignmentRepository.new.about(current_user.id)
  end

  def show
    authorize! @assignment, with: ReviewAssignmentPolicy

    @questions = QuestionSet.questions
    @response = ReviewResponseRepository.new.for_assignment(@assignment.id).first
    @reviewing_as_reviewer = reviewing_as_reviewer?

    if @assignment.upward? && @reviewing_as_reviewer
      @single_report_warning = Reviews::AnonymityRiskChecker.new.single_direct_report?(@assignment.subject_id)
    end
  end

  def create
    authorize! @assignment, with: ReviewAssignmentPolicy, to: :submit?

    Reviews::SubmissionService.new.submit(
      assignment: @assignment,
      submitter_id: current_user.id,
      answers: answer_params
    )
    redirect_to assignments_path, notice: "Response submitted."
  rescue Reviews::SubmissionService::NotEligible, Reviews::SubmissionService::NotAssignedReviewer
    render_forbidden
  rescue Reviews::SubmissionService::AlreadyFinalized
    redirect_to assignment_path(@assignment), alert: "This review has already been submitted."
  end
  alias_method :update, :create

  private

  def set_assignment
    @assignment = ReviewAssignmentRepository.new.find_by_id(params[:assignment_id] || params[:id])
    render plain: "Not found", status: :not_found and return if @assignment.nil?
  end

  def reviewing_as_reviewer?
    @assignment.reviewer_id == current_user.id
  end

  def answer_params
    (params[:answers] || {}).to_unsafe_h
  end
end
