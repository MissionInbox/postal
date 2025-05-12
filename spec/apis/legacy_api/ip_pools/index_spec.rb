# frozen_string_literal: true

require "rails_helper"

describe "GET /api/v1/servers/ip_pools" do
  context "with a credential" do
    let(:credential) { create(:credential) }
    let(:ip_pool) { create(:ip_pool) }
    let(:ip_address) { create(:ip_address) }

    before do
      # Add IP pool to organization
      credential.server.organization.ip_pools << ip_pool
      
      # Add IP address to IP pool
      ip_pool.ip_addresses << ip_address
    end

    it "returns a list of IP pools" do
      get "/api/v1/servers/ip_pools", params: { key: credential.key }
      expect(response).to have_json_response
      expect(json_response[:status]).to eq "success"
      expect(json_response[:data][:ip_pools]).to be_an Array
      expect(json_response[:data][:ip_pools].length).to eq 1
      
      pool = json_response[:data][:ip_pools][0]
      expect(pool[:uuid]).to eq ip_pool.uuid
      expect(pool[:name]).to eq ip_pool.name
      
      expect(pool[:ip_addresses]).to be_an Array
      expect(pool[:ip_addresses].length).to eq 1
      
      ip = pool[:ip_addresses][0]
      expect(ip[:ipv4]).to eq ip_address.ipv4
      expect(ip[:hostname]).to eq ip_address.hostname
    end
  end

  context "without a credential" do
    it "returns an error message" do
      get "/api/v1/servers/ip_pools"
      expect(response).to have_json_response
      expect(json_response[:status]).to eq "error"
      expect(json_response[:data][:code]).to eq "InvalidServerAPIKey"
    end
  end
end