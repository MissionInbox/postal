#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for MX-based batch_key functionality
require_relative "config/environment"

puts "=" * 80
puts "Testing MX-based batch_key generation"
puts "=" * 80
puts

# Test 1: Check MX resolution for common domains
test_domains = [
  "gmail.com",
  "googlemail.com", # Should have same MX as gmail.com
  "yahoo.com",
  "outlook.com",
  "hotmail.com", # Should have same MX as outlook.com
  "example.com"
]

puts "Test 1: Resolving MX records for test domains"
puts "-" * 80

mx_hashes = {}
test_domains.each do |domain|
  begin
    hash = Postal::MessageDB::Message.mx_hash_for_domain(domain)
    mx_hashes[domain] = hash

    # Also get the actual MX records
    mx_records = DNSResolver.local.mx(domain, raise_timeout_errors: false)
    mx_hosts = mx_records.map(&:last).sort

    puts "Domain: #{domain.ljust(20)} | Hash: #{hash || 'nil'.ljust(16)} | MX: #{mx_hosts.join(', ')}"
  rescue StandardError => e
    puts "Domain: #{domain.ljust(20)} | Error: #{e.message}"
  end
end

puts
puts "Test 2: Checking for matching hashes (domains with same MX servers)"
puts "-" * 80

grouped = mx_hashes.group_by { |_domain, hash| hash }
grouped.each do |hash, domains|
  next if domains.length <= 1

  domain_names = domains.map(&:first)
  puts "✓ Domains with matching hash #{hash}: #{domain_names.join(', ')}"
  puts "  → These will be batched together!"
end

if grouped.all? { |_hash, domains| domains.length == 1 }
  puts "ℹ No domains share the same MX servers in this test set"
end

puts
puts "Test 3: Testing cache functionality"
puts "-" * 80

domain = "gmail.com"

# First call (should hit DNS)
start_time = Time.now
hash1 = Postal::MessageDB::Message.mx_hash_for_domain(domain)
time1 = (Time.now - start_time) * 1000

# Second call (should hit cache)
start_time = Time.now
hash2 = Postal::MessageDB::Message.mx_hash_for_domain(domain)
time2 = (Time.now - start_time) * 1000

puts "First call (DNS):  #{time1.round(2)}ms → #{hash1}"
puts "Second call (cache): #{time2.round(2)}ms → #{hash2}"
puts "Cache working: #{hash1 == hash2 && time2 < time1 ? '✓ YES' : '✗ NO'}"

puts
puts "Test 4: Simulating batch_key generation for outgoing messages"
puts "-" * 80

# Create a mock server and message database
server = Server.first
if server
  test_messages = [
    { rcpt_to: "user1@gmail.com", scope: "outgoing" },
    { rcpt_to: "user2@googlemail.com", scope: "outgoing" },
    { rcpt_to: "user3@yahoo.com", scope: "outgoing" },
    { rcpt_to: "user4@gmail.com", scope: "outgoing" }
  ]

  puts "Message batching simulation:"
  test_messages.each do |msg_data|
    domain = msg_data[:rcpt_to].split("@").last
    mx_hash = Postal::MessageDB::Message.mx_hash_for_domain(domain)
    batch_key = "outgoing-#{mx_hash || domain}"

    puts "  #{msg_data[:rcpt_to].ljust(30)} → batch_key: #{batch_key}"
  end

  puts
  puts "Expected behavior:"
  puts "  • user1@gmail.com and user4@gmail.com should have the same batch_key"
  puts "  • If gmail.com and googlemail.com share MX servers, they'll batch together"
  puts "  • user3@yahoo.com will have a different batch_key"
else
  puts "⚠ No server found in database. Skipping message simulation."
end

puts
puts "=" * 80
puts "Test complete!"
puts "=" * 80
