module Reviews
  # Shared write path for both the web ReviewsController and the Slack
  # view_submission handler -- keeps eligibility checking, encryption, and
  # the finalize-then-immutable rule in one place regardless of which
  # channel the submission came through.
  class SubmissionService
    class NotEligible < StandardError; end
    class NotAssignedReviewer < StandardError; end
    class AlreadyFinalized < StandardError; end

    def initialize(
      assignment_repository: ReviewAssignmentRepository.new,
      response_repository: ReviewResponseRepository.new,
      eligibility_checker: Reviews::EligibilityChecker.new,
      encryptor: Crypto::ResponseEncryptor.new
    )
      @assignment_repository = assignment_repository
      @response_repository = response_repository
      @eligibility_checker = eligibility_checker
      @encryptor = encryptor
    end

    # answers: hash of question_id => rating (1-5) or freeform text, per
    # QuestionSet.questions. Editable/re-submittable until finalize: true;
    # immutable after (see plan doc's "response editability" assumption).
    def submit(assignment:, submitter_id:, answers:, finalize: true)
      raise NotAssignedReviewer unless submitter_id == assignment.reviewer_id

      eligible = eligibility_checker.eligible?(
        reviewer_id: assignment.reviewer_id,
        subject_id: assignment.subject_id,
        direction: assignment.direction
      )
      raise NotEligible unless eligible

      existing = response_repository.for_assignment(assignment.id).first
      raise AlreadyFinalized if existing&.finalized?

      response_id = existing&.id || SecureRandom.uuid
      envelopes = encryptor.build_envelopes(
        response_id: response_id,
        answers: answers,
        attestation: { "submitter_user_id" => submitter_id, "verified_direct_report" => eligible }
      )

      response = ReviewResponse.new(
        id: response_id,
        assignment_id: assignment.id,
        answers_envelope: envelopes[:answers_envelope],
        attestation_envelope: envelopes[:attestation_envelope],
        question_set_version: QuestionSet.current_version,
        finalized: finalize
      )
      response_repository.save(response)

      if finalize
        assignment.status = "submitted"
        assignment_repository.save(assignment)
      end

      response
    end

    private

    attr_reader :assignment_repository, :response_repository, :eligibility_checker, :encryptor
  end
end
