#!/usr/bin/ruby

require "json"
require "net/http"
require "openssl"
require "pp"

class Gandy

    class Gandy::HTTPException < Exception
        def initialize(err)
            @err = err
        end
        def response()
            return @err
        end

        def msg()
            pp @err.body.to_json+" lol"
            return @err.body.to_json["message"]
        end
    end

    DEFAULT_OPTIONS = {
        use_ssl: true,
        verify_mode: OpenSSL::SSL::VERIFY_PEER,
        keep_alive_timeout: 30,
    }

    API_ENDPOINT  = "https://dns.api.gandi.net/api/v5/"
	
    def initialize(api_key)
        @api_key = api_key
        @server = nil
    end

    def fetch(location:)
        uri = URI(API_ENDPOINT+location)

        req = Net::HTTP::Get.new(uri)
        req['X-Api-Key'] = @api_key

        http = Net::HTTP.new(uri.hostname, uri.port)
        http.use_ssl = true
        res = http.request(req)
        return JSON.parse(res.body)
    end

    def put(location:, params:nil)
        uri = URI(API_ENDPOINT+location)

        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
        req['X-Api-Key'] = @api_key
        req.body = params.to_json

        http = Net::HTTP.new(uri.hostname, uri.port)
        http.use_ssl = true
        res = http.request(req)
        json = JSON.parse(res.body)

        case res.code
        when /^2..$/
        when /^4..$/
            raise Gandy::HTTPException.new(res)
        end
        
        if json["status"] == "error"
            error_msg = "PUT #{location} failed with error:\n"
            json["errors"].each do |e|
                error_msg << e["description"]+"\n" 
            end
            raise Exception.new(error_msg)

        end
        
        return json
    end

    def delete(location:)
        uri = URI(API_ENDPOINT+location)

        req = Net::HTTP::Delete.new(uri)
        req['X-Api-Key'] = @api_key

        http = Net::HTTP.new(uri.hostname, uri.port)
        http.use_ssl = true
        res = http.request(req)
        json = {}
        if res.body
            json = JSON.parse(res.body)
        end
        
        if json["status"] == "error"
            error_msg = "PUT #{location} failed with error:\n"
            json["errors"].each do |e|
                error_msg << e["description"]+"\n" 
            end
            raise Exception.new(error_msg)
        end
        
        return json
    end

    def list_domains()
        return fetch(location: "/domains")
    end

    def get_domain(domain:)
        return fetch(location: "/domains/#{domain}")
    end

    def get_zone_uuid(domain:)
        return get_domain(domain: domain)["zone_uuid"]
    end

    def get_zone_records(zone_uuid:)
        return fetch(location: "/zones/#{zone_uuid}/records")
    end

    def get_zone_record(zone_uuid:, record_name:, record_type:)
        return fetch(location: "/zones/#{zone_uuid}/records/#{record_name}/#{record_type}")
    end

    def get_domain_record(domain:, record_name:, record_type:)
        zone_uuid = get_zone_uuid(domain: domain)
        return fetch(location: "/zones/#{zone_uuid}/records/#{record_name}/#{record_type}")
    end

    def add_record_to_zone(zone_uuid:, record_name:, record_type:, record_value:, record_ttl:10800)
        data = {
			"rrset_name": record_name,
            "rrset_type": record_type,
            "rrset_ttl": record_ttl,
            "rrset_values": [record_value]
        }
        resp = put(location: "/zones/#{zone_uuid}/records", params:data)
        return resp
    end

    def del_record_from_zone(zone_uuid:, record_name:, record_type:)
        resp = delete(location: "/zones/#{zone_uuid}/records/#{record_name}/#{record_type}")
        return resp
    end

    def update_domain_txt(domain:, record_name:, record_value:, record_ttl:10800)
        zone_uuid = get_zone_uuid(domain: domain)
        begin
            resp = add_record_to_zone(zone_uuid: zone_uuid, record_name: record_name, record_type:"TXT", record_value: record_value, record_ttl:record_ttl)
        rescue Gandy::HTTPException => e
            if e.response.class == Net::HTTPConflict
                puts "WARN: #{e.msg}"
                del_record_from_zone(zone_uuid: zone_uuid, record_name:record_name, record_type:"TXT")
                resp = add_record_to_zone(zone_uuid: zone_uuid, record_name: record_name, record_type:"TXT", record_value: record_value, record_ttl:record_ttl)
            end
        end
        if resp["message"] == "A DNS Record already exists with same value"
            puts "WARN: #{resp["message"]}"
            del_record_from_zone(zone_uuid: zone_uuid, record_name:record_name, record_type:"TXT")
            resp = add_record_to_zone(zone_uuid: zone_uuid, record_name: record_name, record_type:"TXT", record_value: record_value, record_ttl:record_ttl)
        end
        return resp
    end
    
    def set_acme_challenge(domain:, challenge:)
        update_domain_txt(domain: domain, record_name:"_acme-challenge", record_value:challenge, record_ttl:300)
    end

    def clear_acme_challenge(domain:)
        zone_uuid = get_zone_uuid(domain: domain)
        del_record_from_zone(zone_uuid: zone_uuid, record_name:"_acme-challenge", record_type:"TXT")
    end

end
