# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /api/v1/organizations/statistics" do
  let!(:organization) { create(:organization) }
  let!(:server) { create(:server, organization: organization) }

  it "returns statistics for a specific organization" do
    get "/api/v1/organizations/statistics", params: {
      params: { organization_uuid: organization.uuid }.to_json
    }

    expect(response.status).to eq(200)
    body = JSON.parse(response.body)
    expect(body["status"]).to eq("success")
    
    statistics = body["data"]["statistics"]
    expect(statistics["uuid"]).to eq(organization.uuid)
    expect(statistics["name"]).to eq(organization.name)
    expect(statistics).to have_key("overall_message_rate")
    expect(statistics).to have_key("total_queued_count")
    expect(statistics).to have_key("total_sent")
    expect(statistics).to have_key("servers_count")
    expect(statistics).to have_key("ip_addresses_count")
    expect(statistics).to have_key("ip_addresses")
    expect(statistics).to have_key("servers")
    
    expect(statistics["servers_count"]).to eq(1)
    expect(statistics["servers"]).to be_an(Array)
    expect(statistics["servers"].first["uuid"]).to eq(server.uuid)
    expect(statistics["servers"].first["name"]).to eq(server.name)
    expect(statistics["servers"].first).to have_key("queued_count")
    expect(statistics["servers"].first).to have_key("message_rate")
    expect(statistics["servers"].first).to have_key("sent_count")
  end

  it "returns an error when organization_uuid is missing" do
    get "/api/v1/organizations/statistics"

    expect(response.status).to eq(200)
    body = JSON.parse(response.body)
    expect(body["status"]).to eq("parameter-error")
  end

  it "returns an error for invalid organization_uuid" do
    get "/api/v1/organizations/statistics", params: {
      params: { organization_uuid: "invalid-uuid" }.to_json
    }

    expect(response.status).to eq(200)
    body = JSON.parse(response.body)
    expect(body["status"]).to eq("error")
    expect(body["data"]["code"]).to eq("InvalidOrganization")
  end
end