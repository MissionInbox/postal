# frozen_string_literal: true

require "rails_helper"

describe "POST /api/v1/servers/ip_pools/create" do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:user) { create(:user, admin: true) }
  let(:credential) { create(:credential, server: server) }
  
  before do
    organization.users << user
    organization.organization_users.where(user_id: user.id).update_all(admin: true)
    # Mocking authentication as we don't have access to the actual request in controller specs
    allow_any_instance_of(LegacyAPI::IPPoolsController).to receive(:current_user).and_return(user)
  end

  context "with valid parameters" do
    it "creates a new IP pool with IP addresses" do
      expect do
        post "/api/v1/servers/ip_pools/create", params: {
          key: credential.key,
          name: "Test Pool",
          ips: ["192.168.1.1", "192.168.1.2"]
        }
      end.to change(IPPool, :count).by(1)
             .and change(IPAddress, :count).by(2)

      expect(response).to have_json_response
      expect(json_response[:status]).to eq "success"
      expect(json_response[:data][:ip_pool][:name]).to eq "Test Pool"
      expect(json_response[:data][:ip_pool][:ip_addresses].length).to eq 2
      expect(json_response[:data][:ip_pool][:ip_addresses][0][:ipv4]).to eq "192.168.1.1"
      expect(json_response[:data][:ip_pool][:ip_addresses][1][:ipv4]).to eq "192.168.1.2"
    end

    it "reuses existing IP addresses" do
      existing_ip = create(:ip_address, ipv4: "192.168.1.1")
      
      expect do
        post "/api/v1/servers/ip_pools/create", params: {
          key: credential.key,
          name: "Test Pool",
          ips: ["192.168.1.1", "192.168.1.2"]
        }
      end.to change(IPPool, :count).by(1)
             .and change(IPAddress, :count).by(1) # Only one new IP

      expect(response).to have_json_response
      expect(json_response[:status]).to eq "success"
      expect(json_response[:data][:ip_pool][:ip_addresses].length).to eq 2
      
      # The existing IP should be associated with the pool
      expect(IPPool.last.ip_addresses).to include(existing_ip)
    end
  end

  context "with invalid parameters" do
    it "fails without a name" do
      post "/api/v1/servers/ip_pools/create", params: {
        key: credential.key,
        ips: ["192.168.1.1"]
      }
      
      expect(response).to have_json_response
      expect(json_response[:status]).to eq "error"
      expect(json_response[:data][:code]).to eq "ParameterError"
    end
    
    it "fails without IPs" do
      post "/api/v1/servers/ip_pools/create", params: {
        key: credential.key,
        name: "Test Pool"
      }
      
      expect(response).to have_json_response
      expect(json_response[:status]).to eq "error"
      expect(json_response[:data][:code]).to eq "ParameterError"
    end
    
    it "fails with invalid IP addresses" do
      post "/api/v1/servers/ip_pools/create", params: {
        key: credential.key,
        name: "Test Pool",
        ips: ["not-an-ip"]
      }
      
      expect(response).to have_json_response
      expect(json_response[:status]).to eq "success"
      expect(json_response[:data][:warnings]).to be_present
    end
  end
end