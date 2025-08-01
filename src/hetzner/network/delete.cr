require "../client"
require "./find"
require "../../util"

class Hetzner::Network::Delete
  include Util

  getter hetzner_client : Hetzner::Client
  getter network_name : String
  getter network_finder : Hetzner::Network::Find

  def initialize(@hetzner_client, @network_name)
    @network_finder = Hetzner::Network::Find.new(@hetzner_client, @network_name)
  end

  def run
    network = network_finder.run

    return handle_missing_network unless network

    log_line "Deleting private network..."
    delete_network(network.id)
    log_line "...private network deleted"

    network_name
  end

  private def handle_missing_network
    log_line "Private network does not exist, skipping delete"
    network_name
  end

  private def delete_network(network_id)
    Retriable.retry(max_attempts: 10, backoff: false, base_interval: 5.seconds) do
      success, response = hetzner_client.delete("/networks", network_id)

      unless success
        STDERR.puts "[#{default_log_prefix}] Failed to delete private network: #{response}"
        STDERR.puts "[#{default_log_prefix}] Retrying to delete private network in 5 seconds..."
        raise "Failed to delete private network"
      end
    end
  end

  private def default_log_prefix
    "Private network"
  end
end
