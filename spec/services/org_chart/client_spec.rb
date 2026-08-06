require "rails_helper"

RSpec.describe OrgChart::Client do
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:http) { Faraday.new { |b| b.adapter :test, stubs } }
  let(:sleeper) { instance_double(Proc, call: nil) }

  subject(:client) do
    described_class.new(http: http, client_id: "id", client_secret: "secret", sleeper: sleeper)
  end

  def stub_token(times: 1)
    times.times do
      stubs.post("/oauth2/token") { [ 200, {}, { access_token: "tok-#{SecureRandom.hex(2)}", expires_in: 600 }.to_json ] }
    end
  end

  it "fetches a token once and reuses it across multiple calls within the TTL" do
    stub_token(times: 1)
    stubs.get("/api/v1/users") { [ 200, {}, { users: [ { "id" => "1" } ], nextPageToken: nil }.to_json ] }
    stubs.get("/api/v1/users") { [ 200, {}, { users: [ { "id" => "2" } ], nextPageToken: nil }.to_json ] }

    client.list_users
    client.list_users

    stubs.verify_stubbed_calls
  end

  it "retries on a 5xx response and succeeds on the next attempt" do
    stub_token(times: 1)
    stubs.get("/api/v1/users") { [ 503, {}, "" ] }
    stubs.get("/api/v1/users") { [ 200, {}, { users: [ { "id" => "1" } ], nextPageToken: nil }.to_json ] }

    result = client.list_users

    expect(result[:users]).to eq([ { "id" => "1" } ])
    expect(sleeper).to have_received(:call).once
  end

  it "gives up and raises after exhausting retries" do
    stub_token(times: 1)
    3.times { stubs.get("/api/v1/users") { [ 503, {}, "" ] } }

    expect { client.list_users }.to raise_error(OrgChart::Client::ApiError)
  end

  it "passes the page_token through to the API request" do
    stub_token(times: 1)
    stubs.get("/api/v1/users?page_size=100&page_token=abc") do
      [ 200, {}, { users: [], nextPageToken: nil }.to_json ]
    end

    client.list_users(page_token: "abc")

    stubs.verify_stubbed_calls
  end
end
