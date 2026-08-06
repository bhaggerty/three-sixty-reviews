require "rails_helper"

RSpec.describe Slack::AnswerExtractor do
  it "extracts a radio_buttons selection by its selected_option value" do
    state_values = { "q1_communication" => { "value" => { "type" => "radio_buttons", "selected_option" => { "value" => "4" } } } }

    expect(described_class.extract(state_values)).to eq("q1_communication" => "4")
  end

  it "extracts a plain_text_input by its value" do
    state_values = { "q6_strengths" => { "value" => { "type" => "plain_text_input", "value" => "Great to work with." } } }

    expect(described_class.extract(state_values)).to eq("q6_strengths" => "Great to work with.")
  end

  it "skips a block with no answered action" do
    state_values = { "q1_communication" => {} }

    expect(described_class.extract(state_values)).to eq({})
  end
end
