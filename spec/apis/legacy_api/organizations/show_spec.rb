# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /api/v1/organizations/show" do
  let!(:organization) { create(:organization) }
  let!(:credential) { create(:credential, server: create(:server, organization: organization)) }

  it "returns details for a specific organization" do
    get "/api/v1/organizations/show", params: {
      params: { uuid: organization.uuid }.to_json
    }, headers: {
      "X-Server-API-Key" => credential.key
    }

    expect(response.status).to eq(200)
    body = JSON.parse(response.body)
    expect(body["status"]).to eq("success")
    expect(body["data"]["organization"]["uuid"]).to eq(organization.uuid)
    expect(body["data"]["organization"]["name"]).to eq(organization.name)
  end

  it "returns an error when uuid is missing" do
    get "/api/v1/organizations/show", headers: {
      "X-Server-API-Key" => credential.key
    }

    expect(response.status).to eq(200)
    body = JSON.parse(response.body)
    expect(body["status"]).to eq("parameter-error")
  end

  it "returns an error for invalid uuid" do
    get "/api/v1/organizations/show", params: {
      params: { uuid: "invalid-uuid" }.to_json
    }, headers: {
      "X-Server-API-Key" => credential.key
    }

    expect(response.status).to eq(200)
    body = JSON.parse(response.body)
    expect(body["status"]).to eq("error")
    expect(body["data"]["code"]).to eq("InvalidOrganization")
  end
end