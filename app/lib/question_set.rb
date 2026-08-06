# Loads the fixed v1 question set (5 rating + 3 freeform) from
# config/review_questions.yml. ReviewCycle/ReviewResponse stamp
# `question_set_version` so a future edit to this file can't corrupt
# rendering of historical responses -- see plan doc.
class QuestionSet
  CONFIG_PATH = Rails.root.join("config", "review_questions.yml")

  class << self
    def current_version
      config["version"]
    end

    def questions
      config["questions"].map(&:symbolize_keys)
    end

    def rating_questions
      questions.select { |q| q[:type] == "rating" }
    end

    def freeform_questions
      questions.select { |q| q[:type] == "freeform" }
    end

    def reset!
      @config = nil
    end

    private

    def config
      @config ||= YAML.load_file(CONFIG_PATH)
    end
  end
end
