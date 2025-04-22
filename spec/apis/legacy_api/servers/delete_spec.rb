# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v1/servers/delete" do
  let!(:organization) { create(:organization) }
  let!(:server) { create(:server, organization: organization) }

  it "deletes a server when given valid organization UUID and server UUID" do
    post "/api/v1/servers/delete", params: {
      params: {
        organization_uuid: organization.uuid,
        server_uuid: server.uuid
      }.to_json
    }

    expect(response.status).to eq(200)
    body = JSON.parse(response.body)
    expect(body["status"]).to eq("success")
    expect(body["data"]["deleted"]).to eq(true)
    expect(body["data"]["server"]["uuid"]).to eq(server.uuid)
    
    # Verify server was soft deleted
    expect(server.reload.deleted_at).not_to be_nil
    expect(Server.present.where(id: server.id).count).to eq(0)
  end
  
  it "returns an error with invalid organization UUID" do
    post "/api/v1/servers/delete", params: {
      params: {
        organization_uuid: "invalid-uuid",
        server_uuid: server.uuid
      }.to_json
    }

    expect(response.status).to eq(200)
    body = JSON.parse(response.body)
    expect(body["status"]).to eq("error")
    expect(body["data"]["code"]).to eq("InvalidOrganization")
    
    # Verify server was not deleted
    expect(server.reload.deleted_at).to be_nil
  end
  
  it "returns an error with invalid server UUID" do
    post "/api/v1/servers/delete", params: {
      params: {
        organization_uuid: organization.uuid,
        server_uuid: "invalid-uuid"
      }.to_json
    }

    expect(response.status).to eq(200)
    body = JSON.parse(response.body)
    expect(body["status"]).to eq("error")
    expect(body["data"]["code"]).to eq("InvalidServer")
    
    # Verify server was not deleted
    expect(server.reload.deleted_at).to be_nil
  end
  
  it "returns an error when parameters are missing" do
    post "/api/v1/servers/delete", params: {
      params: {
        organization_uuid: organization.uuid
        # Missing server_uuid
      }.to_json
    }

    expect(response.status).to eq(200)
    body = JSON.parse(response.body)
    expect(body["status"]).to eq("parameter-error")
    
    # Verify server was not deleted
    expect(server.reload.deleted_at).to be_nil
  end
end