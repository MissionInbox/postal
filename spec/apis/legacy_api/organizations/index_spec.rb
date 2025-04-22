# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /api/v1/organizations/list" do
  let!(:organization) { create(:organization) }
  let!(:credential) { create(:credential, server: create(:server, organization: organization)) }

  it "returns a list of organizations" do
    get "/api/v1/organizations/list", headers: {
      "X-Server-API-Key" => credential.key
    }

    expect(response.status).to eq(200)
    body = JSON.parse(response.body)
    expect(body["status"]).to eq("success")
    expect(body["data"]["organizations"].size).to be >= 1
  end
end