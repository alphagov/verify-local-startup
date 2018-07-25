#!/usr/bin/env ruby

require 'webrick'
require 'net/http'

class Aggregator < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    # Decode hex entity ID
    hex_entity_id = request.path[1..-1].split('/').last
    entity_id = [hex_entity_id].pack('H*')
    uri = URI(entity_id)
    response.body = Net::HTTP.get(uri)
  end
end

aggregated_metadata_server = WEBrick::HTTPServer.new(:Port => 80)
aggregated_metadata_server.mount("/", Aggregator)
aggregated_metadata_server.start
