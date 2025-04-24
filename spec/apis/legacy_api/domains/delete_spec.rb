# frozen_string_literal: true

require "rails_helper"

describe "Legacy API - Domains API" do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server, type: "API") }
  let(:headers) { { "X-Server-API-Key" => credential.key } }

  context "DELETE domain endpoints" do
    let!(:domain) { create(:domain, server: server) }

    it "deletes an existing domain using URL parameter" do
      delete "/api/v1/domains/delete/#{domain.name}", headers: headers
      expect(response.status).to eq(200)
      
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("success")
      expect(json["data"]["deleted"]).to eq(true)
      expect(json["data"]["domain"]["uuid"]).to eq(domain.uuid)
      expect(json["data"]["domain"]["name"]).to eq(domain.name)
      
      # Verify the domain was actually deleted from the database
      expect(server.domains.find_by(name: domain.name)).to be_nil
    end
    
    it "deletes an existing domain using request body" do
      # Create a new domain since the previous test deleted it
      new_domain = create(:domain, server: server)
      
      params = { name: new_domain.name }
      post "/api/v1/domains/delete", params: { params: params.to_json }, headers: headers
      expect(response.status).to eq(200)
      
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("success")
      expect(json["data"]["deleted"]).to eq(true)
      expect(json["data"]["domain"]["uuid"]).to eq(new_domain.uuid)
      expect(json["data"]["domain"]["name"]).to eq(new_domain.name)
      
      # Verify the domain was actually deleted from the database
      expect(server.domains.find_by(name: new_domain.name)).to be_nil
    end

    it "returns error if domain name is not found" do
      delete "/api/v1/domains/delete/nonexistent-domain.com", headers: headers
      expect(response.status).to eq(200)
      
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("error")
      expect(json["data"]["code"]).to eq("InvalidDomain")
    end
    
    it "returns error if name parameter is missing" do
      post "/api/v1/domains/delete", headers: headers
      expect(response.status).to eq(200)
      
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("parameter-error")
      expect(json["data"]["message"]).to include("required")
    end
  end
end