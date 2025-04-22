# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v1/servers/create" do
  let!(:organization) { create(:organization) }
  let!(:credential) { create(:credential, server: create(:server, organization: organization)) }

  context "with valid parameters" do
    before do
      allow_any_instance_of(Postal::MessageDB::Provisioner).to receive(:provision).and_return(true)
    end

    it "creates a new server" do
      expect {
        post "/api/v1/servers/create", params: {
          params: {
            organization_uuid: organization.uuid,
            name: "Test Server",
            mode: "Live",
            skip_provision_database: true
          }.to_json
        }, headers: {
          "X-Server-API-Key" => credential.key
        }
      }.to change { Server.count }.by(1)

      expect(response.status).to eq(200)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("success")
      expect(body["data"]["server"]["name"]).to eq("Test Server")
      expect(body["data"]["server"]["organization"]["uuid"]).to eq(organization.uuid)
    end
  end

  context "with invalid parameters" do
    it "returns an error when organization_uuid is missing" do
      post "/api/v1/servers/create", params: {
        params: { name: "Test Server" }.to_json
      }, headers: {
        "X-Server-API-Key" => credential.key
      }

      expect(response.status).to eq(200)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("parameter-error")
    end

    it "returns an error when name is missing" do
      post "/api/v1/servers/create", params: {
        params: { organization_uuid: organization.uuid }.to_json
      }, headers: {
        "X-Server-API-Key" => credential.key
      }

      expect(response.status).to eq(200)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("parameter-error")
    end

    it "returns an error for invalid organization_uuid" do
      post "/api/v1/servers/create", params: {
        params: { organization_uuid: "invalid-uuid", name: "Test Server" }.to_json
      }, headers: {
        "X-Server-API-Key" => credential.key
      }

      expect(response.status).to eq(200)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("error")
      expect(body["data"]["code"]).to eq("InvalidOrganization")
    end
  end
end