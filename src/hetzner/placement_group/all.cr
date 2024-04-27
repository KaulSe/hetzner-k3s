require "../client"
require "../placement_group"
require "../placement_groups_list"

class Hetzner::PlacementGroup::All
  getter hetzner_client : Hetzner::Client

  def initialize(@hetzner_client)
  end

  def run : Array(Hetzner::PlacementGroup)
    fetch_placement_groups
  end

  def delete_unused
    all_placement_groups = fetch_placement_groups

    all_placement_groups.reject! do |placement_group|
      if placement_group.servers.size == 0
        Hetzner::PlacementGroup::Delete.new(hetzner_client, placement_group: placement_group ).run
        true
      else
        false
      end
    end

    all_placement_groups
  end

  def delete_all
    fetch_placement_groups.each do |placement_group|
      Hetzner::PlacementGroup::Delete.new(hetzner_client, placement_group: placement_group ).run
    end
  end

  private def fetch_placement_groups
    Retriable.retry(max_attempts: 10, backoff: false, base_interval: 5.seconds) do
      success, response = hetzner_client.get("/placement_groups", { :per_page => 100 })

      if success
        PlacementGroupsList.from_json(response).placement_groups
      else
        STDERR.puts "[#{default_log_prefix}] Failed to fetch placement groups: #{response}"
        STDERR.puts "[#{default_log_prefix}] Retrying to fetch placement groups in 5 seconds..."
        raise "Failed to fetch placement groups"
      end
    end
  end

  private def default_log_prefix
    "Placement groups"
  end
end
