# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v1/servers/create" do
  let!(:organization) { create(:organization) }

  context "with valid parameters" do
    before do
      allow_any_instance_of(Postal::MessageDB::Provisioner).to receive(:provision).and_return(true)
    end

    it "creates a new server using organization UUID as authentication" do
      expect {
        post "/api/v1/servers/create", params: {
          params: {
            organization_uuid: organization.uuid,
            name: "Test Server",
            mode: "Live",
            skip_provision_database: true
          }.to_json
        }
      }.to change { Server.count }.by(1)
        .and change { Credential.count }.by(1)

      expect(response.status).to eq(200)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("success")
      expect(body["data"]["server"]["name"]).to eq("Test Server")
      expect(body["data"]["server"]["organization"]["uuid"]).to eq(organization.uuid)
      expect(body["data"]["server"]["api_key"]).to be_present
      expect(body["data"]["server"]["api_key"].length).to eq(24)
    end
  end

  context "with invalid parameters" do
    it "returns an error when organization_uuid is missing" do
      post "/api/v1/servers/create", params: {
        params: { name: "Test Server" }.to_json
      }

      expect(response.status).to eq(200)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("parameter-error")
    end

    it "returns an error when name is missing" do
      post "/api/v1/servers/create", params: {
        params: { organization_uuid: organization.uuid }.to_json
      }

      expect(response.status).to eq(200)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("parameter-error")
    end

    it "returns an error for invalid organization_uuid" do
      post "/api/v1/servers/create", params: {
        params: { organization_uuid: "invalid-uuid", name: "Test Server" }.to_json
      }

      expect(response.status).to eq(200)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("error")
      expect(body["data"]["code"]).to eq("InvalidOrganization")
    end
  end
end