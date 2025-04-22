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
      expect(body["data"]["server"]["already_exists"]).to eq(false)
    end
    
    it "returns an existing server with API key when name already exists" do
      # First create a server
      server = organization.servers.create!(name: "Existing Server", mode: "Live")
      
      # Then try to create a server with the same name
      expect {
        post "/api/v1/servers/create", params: {
          params: {
            organization_uuid: organization.uuid,
            name: "Existing Server",
            mode: "Live",
            skip_provision_database: true
          }.to_json
        }
      }.to change { Server.count }.by(0)
        .and change { Credential.count }.by(1) # It should create an API credential for the existing server
      
      expect(response.status).to eq(200)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("success")
      expect(body["data"]["server"]["name"]).to eq("Existing Server")
      expect(body["data"]["server"]["uuid"]).to eq(server.uuid)
      expect(body["data"]["server"]["api_key"]).to be_present
      expect(body["data"]["server"]["already_exists"]).to eq(true)
    end
    
    it "returns an existing server with existing API key when name already exists and API key exists" do
      # First create a server with an API credential
      server = organization.servers.create!(name: "Existing Server With API", mode: "Live")
      api_credential = server.credentials.create!(type: "API", name: "Existing API Credential", key: "existingkey123456789012345")
      
      # Then try to create a server with the same name
      expect {
        post "/api/v1/servers/create", params: {
          params: {
            organization_uuid: organization.uuid,
            name: "Existing Server With API",
            mode: "Live",
            skip_provision_database: true
          }.to_json
        }
      }.to change { Server.count }.by(0)
        .and change { Credential.count }.by(0) # It should not create new credentials
      
      expect(response.status).to eq(200)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("success")
      expect(body["data"]["server"]["name"]).to eq("Existing Server With API")
      expect(body["data"]["server"]["uuid"]).to eq(server.uuid)
      expect(body["data"]["server"]["api_key"]).to eq(api_credential.key)
      expect(body["data"]["server"]["already_exists"]).to eq(true)
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