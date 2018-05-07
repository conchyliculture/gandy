#!/usr/bin/ruby

require_relative "./gandy.rb"

action = ARGV[0]
domain = ARGV[1]

gandi_key_path = File.join(File.dirname(__FILE__), '/.apikey')
unless File.exist?(gandi_key_path)
    $stderr.puts "Need a Gandi API key in #{gandi_key_path}"
    $stderr.puts "See https://doc.livedns.gandi.net/"
    exit
end

api_key = File.read(gandi_key_path).strip()
g = Gandy.new(api_key)

case action
when "update"
    challenge = ARGV[2]
    g.set_acme_challenge(domain: domain, challenge: challenge)
when "cleanup"
    g.clear_acme_challenge(domain: domain)
end
