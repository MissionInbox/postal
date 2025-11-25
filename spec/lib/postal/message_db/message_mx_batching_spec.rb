# frozen_string_literal: true

require "rails_helper"

RSpec.describe Postal::MessageDB::Message, "#batch_key with MX-based batching" do
  let(:server) { create(:server) }
  let(:message_db) { server.message_db }

  describe ".mx_hash_for_domain" do
    context "when domain has MX records" do
      before do
        allow(DNSResolver.local).to receive(:mx).with("example.com", raise_timeout_errors: false)
          .and_return([[10, "mail1.example.com"], [20, "mail2.example.com"]])
      end

      it "returns a hash based on sorted MX hostnames" do
        hash = described_class.mx_hash_for_domain("example.com")
        expect(hash).to be_a(String)
        expect(hash.length).to eq(16)
      end

      it "returns consistent hash for same MX records" do
        hash1 = described_class.mx_hash_for_domain("example.com")
        hash2 = described_class.mx_hash_for_domain("example.com")
        expect(hash1).to eq(hash2)
      end

      it "ignores MX priority and sorts by hostname" do
        # Different priorities but same hosts should give same hash
        allow(DNSResolver.local).to receive(:mx).with("domain1.com", raise_timeout_errors: false)
          .and_return([[10, "mail1.example.com"], [20, "mail2.example.com"]])
        allow(DNSResolver.local).to receive(:mx).with("domain2.com", raise_timeout_errors: false)
          .and_return([[5, "mail1.example.com"], [15, "mail2.example.com"]])

        hash1 = described_class.mx_hash_for_domain("domain1.com")
        hash2 = described_class.mx_hash_for_domain("domain2.com")
        expect(hash1).to eq(hash2)
      end

      it "produces different hashes for different MX records" do
        allow(DNSResolver.local).to receive(:mx).with("domain1.com", raise_timeout_errors: false)
          .and_return([[10, "mail1.example.com"]])
        allow(DNSResolver.local).to receive(:mx).with("domain2.com", raise_timeout_errors: false)
          .and_return([[10, "mail2.example.com"]])

        hash1 = described_class.mx_hash_for_domain("domain1.com")
        hash2 = described_class.mx_hash_for_domain("domain2.com")
        expect(hash1).not_to eq(hash2)
      end
    end

    context "when domain has no MX records" do
      before do
        allow(DNSResolver.local).to receive(:mx).with("nomail.com", raise_timeout_errors: false)
          .and_return([])
      end

      it "returns nil" do
        hash = described_class.mx_hash_for_domain("nomail.com")
        expect(hash).to be_nil
      end
    end

    context "when domain is blank" do
      it "returns nil for nil" do
        expect(described_class.mx_hash_for_domain(nil)).to be_nil
      end

      it "returns nil for empty string" do
        expect(described_class.mx_hash_for_domain("")).to be_nil
      end
    end

    context "when DNS resolution fails" do
      before do
        allow(DNSResolver.local).to receive(:mx).and_raise(StandardError.new("DNS timeout"))
        allow(Postal.logger).to receive(:warn)
      end

      it "returns nil" do
        hash = described_class.mx_hash_for_domain("error.com")
        expect(hash).to be_nil
      end

      it "logs a warning" do
        described_class.mx_hash_for_domain("error.com")
        expect(Postal.logger).to have_received(:warn).with(/Failed to resolve MX/)
      end
    end

    context "caching behavior" do
      before do
        # Clear the cache before these tests
        described_class.instance_variable_set(:@mx_cache, {})
        described_class.instance_variable_set(:@mx_cache_access_count, 0)

        allow(DNSResolver.local).to receive(:mx).with("cached.com", raise_timeout_errors: false)
          .and_return([[10, "mail.cached.com"]])
      end

      it "caches results for repeated calls" do
        described_class.mx_hash_for_domain("cached.com")
        described_class.mx_hash_for_domain("cached.com")

        # DNS should only be called once
        expect(DNSResolver.local).to have_received(:mx).once
      end

      it "expires cache after TTL" do
        hash1 = described_class.mx_hash_for_domain("cached.com")

        # Simulate time passing (modify the cache entry)
        cache = described_class.mx_cache
        cache["mx_hash:cached.com"][:expires_at] = Time.now - 1.second

        hash2 = described_class.mx_hash_for_domain("cached.com")

        expect(hash1).to eq(hash2)
        # DNS should be called twice (initial + after expiry)
        expect(DNSResolver.local).to have_received(:mx).twice
      end
    end
  end

  describe "#batch_key" do
    context "for outgoing messages" do
      let(:message) do
        MessageFactory.outgoing(server, rcpt_to: "user@example.com")
      end

      before do
        allow(DNSResolver.local).to receive(:mx).with("example.com", raise_timeout_errors: false)
          .and_return([[10, "mail.example.com"]])
      end

      it "uses MX hash in batch_key" do
        mx_hash = described_class.mx_hash_for_domain("example.com")
        expect(message.batch_key).to eq("outgoing-#{mx_hash}")
      end

      it "batches messages to different domains with same MX servers" do
        allow(DNSResolver.local).to receive(:mx).with("domain1.com", raise_timeout_errors: false)
          .and_return([[10, "mail.shared.com"]])
        allow(DNSResolver.local).to receive(:mx).with("domain2.com", raise_timeout_errors: false)
          .and_return([[10, "mail.shared.com"]])

        message1 = MessageFactory.outgoing(server, rcpt_to: "user@domain1.com")
        message2 = MessageFactory.outgoing(server, rcpt_to: "user@domain2.com")

        expect(message1.batch_key).to eq(message2.batch_key)
      end

      it "falls back to domain-based batching when MX resolution fails" do
        allow(DNSResolver.local).to receive(:mx).with("example.com", raise_timeout_errors: false)
          .and_return([])
        allow(Postal.logger).to receive(:warn)

        expect(message.batch_key).to eq("outgoing-example.com")
      end
    end

    context "for incoming messages" do
      let(:route) { create(:route, server: server) }
      let(:endpoint) { create(:http_endpoint, server: server) }
      let(:message) do
        msg = MessageFactory.incoming(server)
        msg.route_id = route.id
        msg.endpoint_id = endpoint.id
        msg.endpoint_type = endpoint.class.name
        msg
      end

      it "uses route and endpoint in batch_key (unchanged behavior)" do
        expected = "incoming-rt:#{route.id}-ep:#{endpoint.id}-#{endpoint.class.name}"
        expect(message.batch_key).to eq(expected)
      end

      it "does not use MX records for incoming messages" do
        expect(DNSResolver.local).not_to receive(:mx)
        message.batch_key
      end
    end

    context "for other message types" do
      let(:message) do
        msg = described_class.new(message_db, {})
        msg.scope = nil
        msg
      end

      it "returns nil" do
        expect(message.batch_key).to be_nil
      end
    end
  end
end
