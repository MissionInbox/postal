require 'rails_helper'

describe LegacyAPI::IPAddressesController, type: :request do
  before do
    @organization = create(:organization)
    @server = create(:server, organization: @organization)
    @ip_pool = create(:ip_pool, organization: @organization)
    @ip_address = create(:ip_address, ip_pool: @ip_pool, ipv4: '192.168.0.1')
    @server.ip_pool = @ip_pool
    @server.save!
    
    # Create an email IP mapping
    @email_mapping_ip = create(:ip_address, ip_pool: @ip_pool, ipv4: '192.168.0.2')
    @email_mapping = create(:email_ip_mapping, server: @server, email_address: 'test@example.com', ip_address: @email_mapping_ip)
    
    # Create an IP pool rule
    @rule_ip_pool = create(:ip_pool, organization: @organization)
    @rule_ip = create(:ip_address, ip_pool: @rule_ip_pool, ipv4: '192.168.0.3')
    @rule = create(:ip_pool_rule, server: @server, ip_pool: @rule_ip_pool)
  end

  context "with a valid server API key" do
    before do
      @credential = create(:credential, server: @server)
    end

    it "should return IPs from IP pool and rules only" do
      get "/api/v1/servers/ip_addresses", params: {
        key: @credential.key
      }, headers: { 'X-Server-API-Key': @credential.key }
      
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json['status']).to eq 'success'
      expect(json['data']['ip_addresses'].size).to eq 2
      
      # Check that our IPs are included
      ip_addresses = json['data']['ip_addresses'].map { |ip| ip['ipv4'] }
      expect(ip_addresses).to include('192.168.0.1')  # From server's IP pool
      expect(ip_addresses).to include('192.168.0.3')  # From IP pool rule
      
      # Email-specific IP should NOT be included
      expect(ip_addresses).not_to include('192.168.0.2')
      
      # Check that ID is not included
      expect(json['data']['ip_addresses'][0].key?('id')).to be false
    end
  end

  context "with an invalid API key" do
    it "should return an error" do
      get "/api/v1/servers/ip_addresses", params: {
        key: 'invalid'
      }, headers: { 'X-Server-API-Key': 'invalid' }
      
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json['status']).to eq 'error'
      expect(json['data']['code']).to eq 'InvalidServerAPIKey'
    end
  end
  
  context "with an organization API key" do
    it "should return an error" do
      get "/api/v1/servers/ip_addresses", params: {
        key: @organization.api_key,
        server: @server.permalink
      }, headers: { 'X-Server-API-Key': @organization.api_key }
      
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json['status']).to eq 'error'
      expect(json['data']['code']).to eq 'InvalidServerAPIKey'
    end
  end
end