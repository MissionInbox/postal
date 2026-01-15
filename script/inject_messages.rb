#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'json'
require 'optparse'
require 'thread'

# Main class for message injection
class PostalMessageInjector
  attr_reader :api_url, :api_key, :options

  def initialize(api_url, api_key, options = {})
    @api_url = api_url
    @api_key = api_key
    @options = default_options.merge(options)
    @stats = { success: 0, failed: 0, errors: [] }
    @queue = Queue.new
    @mutex = Mutex.new
  end

  def run
    puts "Injecting #{options[:count]} messages..."
    puts "From: #{options[:from]}"
    puts "To: #{options[:to]}"
    puts "Concurrency: #{options[:concurrency]} threads"
    puts "Rate limit: #{options[:rate_limit]} req/s"
    puts ""

    start_time = Time.now

    # Start worker threads
    workers = options[:concurrency].times.map do |i|
      Thread.new { worker_loop(i) }
    end

    # Queue messages
    options[:count].times do |i|
      @queue << i + 1
    end

    # Signal completion
    options[:concurrency].times { @queue << :stop }

    # Wait for workers
    workers.each(&:join)

    elapsed = Time.now - start_time
    report_stats(elapsed)
  end

  private

  def worker_loop(worker_id)
    loop do
      msg_num = @queue.pop
      break if msg_num == :stop

      send_message(msg_num)

      # Rate limiting
      sleep(1.0 / options[:rate_limit]) if options[:rate_limit] > 0
    end
  end

  def send_message(num)
    payload = generate_payload(num)

    retries = 0
    begin
      response = make_api_request(payload)
      record_success
      puts "✓ Sent message #{num}" if num % 100 == 0
    rescue => e
      retries += 1
      if retries <= options[:retry_attempts]
        sleep(options[:retry_delay] * retries)
        retry
      else
        record_failure(num, e)
      end
    end
  end

  def generate_payload(num)
    {
      to: [options[:to]],
      from: options[:from],
      subject: "#{options[:subject_prefix]} ##{num} - #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}",
      plain_body: generate_body(num)
    }.tap do |p|
      p[:priority] = options[:priority] if options[:priority]
      p[:tag] = options[:tag] if options[:tag]
    end
  end

  def generate_body(num)
    base = options[:body_template] || "This is test message number #{num}."

    if options[:randomize_body]
      base + "\n\n" + lorem_ipsum + "\n\nRandom: #{rand(1000000)}"
    else
      base
    end
  end

  def make_api_request(payload)
    uri = URI("#{api_url}/api/v1/send/message")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path)
    request['X-Server-API-Key'] = api_key
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json

    response = http.request(request)

    unless response.code.to_i == 200
      raise "API Error: #{response.code} - #{response.body}"
    end

    JSON.parse(response.body)
  end

  def record_success
    @mutex.synchronize { @stats[:success] += 1 }
  end

  def record_failure(num, error)
    @mutex.synchronize do
      @stats[:failed] += 1
      @stats[:errors] << { num: num, error: error.message }
      puts "✗ Failed message #{num}: #{error.message}"
    end
  end

  def report_stats(elapsed)
    puts "\n" + "=" * 50
    puts "Injection Complete"
    puts "=" * 50
    puts "Total messages: #{options[:count]}"
    puts "Successful: #{@stats[:success]}"
    puts "Failed: #{@stats[:failed]}"
    puts "Time elapsed: #{elapsed.round(2)}s"
    puts "Rate: #{(@stats[:success] / elapsed).round(2)} msg/s"

    if @stats[:failed] > 0
      puts "\nErrors (showing first 10):"
      @stats[:errors].first(10).each do |e|
        puts "  Message #{e[:num]}: #{e[:error]}"
      end
    end
  end

  def lorem_ipsum
    sentences = [
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
      "Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
      "Ut enim ad minim veniam, quis nostrud exercitation ullamco.",
      "Duis aute irure dolor in reprehenderit in voluptate velit.",
      "Excepteur sint occaecat cupidatat non proident sunt in culpa.",
      "Sed ut perspiciatis unde omnis iste natus error sit voluptatem.",
      "Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit.",
      "Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet.",
      "At vero eos et accusamus et iusto odio dignissimos ducimus.",
      "Et harum quidem rerum facilis est et expedita distinctio."
    ]
    sentences.sample(3).join(" ")
  end

  def default_options
    {
      count: 10000,
      from: 'test@apple.missioninbox.tech',
      to: 'lin@beta.obmengine.com',
      subject_prefix: 'Test Message',
      body_template: nil,
      randomize_body: true,
      concurrency: 10,
      rate_limit: 100,
      retry_attempts: 3,
      retry_delay: 1,
      priority: nil,
      tag: nil
    }
  end
end

# Parse command-line options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: inject_messages.rb [options]"
  opts.separator ""
  opts.separator "Required options:"

  opts.on("--api-url URL", "Postal API URL (e.g., https://cobalt.obmengine.com)") { |v| options[:api_url] = v }
  opts.on("--api-key KEY", "Server API Key") { |v| options[:api_key] = v }

  opts.separator ""
  opts.separator "Message options:"

  opts.on("--count N", Integer, "Number of messages (default: 10000)") { |v| options[:count] = v }
  opts.on("--from EMAIL", "From address (default: test@apple.missioninbox.tech)") { |v| options[:from] = v }
  opts.on("--to EMAIL", "To address (default: lin@beta.obmengine.com)") { |v| options[:to] = v }
  opts.on("--subject PREFIX", "Subject prefix (default: 'Test Message')") { |v| options[:subject_prefix] = v }
  opts.on("--body TEMPLATE", "Body template text") { |v| options[:body_template] = v }
  opts.on("--no-randomize", "Don't randomize body text") { options[:randomize_body] = false }

  opts.separator ""
  opts.separator "Performance options:"

  opts.on("--concurrency N", Integer, "Number of parallel threads (default: 10)") { |v| options[:concurrency] = v }
  opts.on("--rate-limit N", Integer, "Max requests per second (default: 100)") { |v| options[:rate_limit] = v }

  opts.separator ""
  opts.separator "Other options:"

  opts.on("--priority N", Integer, "Message priority (higher = processed sooner)") { |v| options[:priority] = v }
  opts.on("--tag TAG", "Custom tag for messages") { |v| options[:tag] = v }
  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end.parse!

# Environment variables fallback
api_url = options.delete(:api_url) || ENV['POSTAL_API_URL']
api_key = options.delete(:api_key) || ENV['POSTAL_API_KEY']

unless api_url && api_key
  puts "Error: --api-url and --api-key required (or set POSTAL_API_URL and POSTAL_API_KEY)"
  puts ""
  puts "Example:"
  puts "  ./script/inject_messages.rb \\"
  puts "    --api-url https://cobalt.obmengine.com \\"
  puts "    --api-key YOUR_API_KEY \\"
  puts "    --count 10000"
  puts ""
  puts "Or with environment variables:"
  puts "  export POSTAL_API_URL=https://cobalt.obmengine.com"
  puts "  export POSTAL_API_KEY=YOUR_API_KEY"
  puts "  ./script/inject_messages.rb --count 10000"
  exit 1
end

# Run injection
injector = PostalMessageInjector.new(api_url, api_key, options)
injector.run
