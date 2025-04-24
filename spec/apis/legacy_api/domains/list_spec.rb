# frozen_string_literal: true

require "rails_helper"

describe "Legacy API - Domains API" do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server, type: "API") }
  let(:headers) { { "X-Server-API-Key" => credential.key } }

  context "GET /api/v1/domains/list" do
    let!(:domains) do
      (1..5).map do |i|
        create(:domain, 
          server: server, 
          name: "domain#{i}.example.com", 
          verified_at: i.even? ? Time.now : nil
        )
      end
    end

    it "lists all domains with pagination" do
      get "/api/v1/domains/list", params: { per_page: 3, page: 1 }, headers: headers
      expect(response.status).to eq(200)
      
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("success")
      expect(json["data"]["domains"].count).to eq(3)
      expect(json["data"]["pagination"]["current_page"]).to eq(1)
      expect(json["data"]["pagination"]["per_page"]).to eq(3)
      expect(json["data"]["pagination"]["total_pages"]).to eq(2)
      expect(json["data"]["pagination"]["total_count"]).to eq(5)
      
      # Check second page
      get "/api/v1/domains/list", params: { per_page: 3, page: 2 }, headers: headers
      expect(response.status).to eq(200)
      
      json = JSON.parse(response.body)
      expect(json["data"]["domains"].count).to eq(2)
      expect(json["data"]["pagination"]["current_page"]).to eq(2)
    end

    it "filters domains by verification status" do
      # Get verified domains
      get "/api/v1/domains/list", params: { verified: true }, headers: headers
      expect(response.status).to eq(200)
      
      json = JSON.parse(response.body)
      expect(json["data"]["domains"].count).to eq(2)
      expect(json["data"]["domains"].all? { |d| d["verified"] == true }).to eq(true)
      
      # Get unverified domains
      get "/api/v1/domains/list", params: { verified: false }, headers: headers
      expect(response.status).to eq(200)
      
      json = JSON.parse(response.body)
      expect(json["data"]["domains"].count).to eq(3)
      expect(json["data"]["domains"].all? { |d| d["verified"] == false }).to eq(true)
    end

    it "searches domains by name" do
      get "/api/v1/domains/list", params: { search: "domain1" }, headers: headers
      expect(response.status).to eq(200)
      
      json = JSON.parse(response.body)
      expect(json["data"]["domains"].count).to eq(1)
      expect(json["data"]["domains"][0]["name"]).to eq("domain1.example.com")
    end

    it "orders domains by specified column" do
      # Order by name ascending
      get "/api/v1/domains/list", params: { order_by: "name", order_direction: "asc" }, headers: headers
      expect(response.status).to eq(200)
      
      json = JSON.parse(response.body)
      domain_names = json["data"]["domains"].map { |d| d["name"] }
      expect(domain_names).to eq(domain_names.sort)
      
      # Order by created_at descending (default)
      get "/api/v1/domains/list", headers: headers
      expect(response.status).to eq(200)
      
      json = JSON.parse(response.body)
      created_times = json["data"]["domains"].map { |d| Time.parse(d["created_at"]) }
      expect(created_times).to eq(created_times.sort.reverse)
    end

    it "limits per_page to prevent excessive queries" do
      get "/api/v1/domains/list", params: { per_page: 200 }, headers: headers
      expect(response.status).to eq(200)
      
      json = JSON.parse(response.body)
      expect(json["data"]["pagination"]["per_page"]).to eq(100) # MAX_PER_PAGE
    end
  end
end