require "crest"
require "yaml"
require "json"

require "./location"
require "./locations_list"
require "./instance_type"
require "./instance_types_list"

class Hetzner::Client
  getter token : String?

  private getter api_url : String = "https://api.hetzner.cloud/v1"
  private getter mutex : Mutex = Mutex.new
  @locations : Array(Location)?
  @instance_types : Array(InstanceType)?

  def initialize(token)
    @token = token
  end

  def locations : Array(Location)
    @locations ||= fetch_locations
  end

  def instance_types : Array(InstanceType)
    @instance_types ||= fetch_instance_types
  end

  private def fetch_locations : Array(Location)
    success, response = get("/locations")

    if success
      Hetzner::LocationsList.from_json(response).locations
    else
      puts "[Preflight checks] Unable to fetch locations via Hetzner API"
      exit 1
    end
  end

  private def fetch_instance_types : Array(InstanceType)
    success, response = get("/server_types")

    if success
      Hetzner::InstanceTypesList.from_json(response).server_types
    else
      puts "[Preflight checks] Unable to fetch instance types via Hetzner API"
      exit 1
    end
  end

  def get(path, params : Hash = {} of Symbol => String | Bool | Nil)
    response = with_rate_limit do
      Crest.get(
        "#{api_url}#{path}",
        params: params,
        json: true,
        headers: headers,
        handle_errors: false
      )
    end

    handle_response(response)
  end

  def post(path, params = {} of KeyType => ValueType)
    response = with_rate_limit do
      Crest.post(
        "#{api_url}#{path}",
        params,
        json: true,
        headers: headers,
        handle_errors: false
      )
    end

    handle_response(response)
  end

  def put(path, params = {} of KeyType => ValueType)
    response = with_rate_limit do
      Crest.put(
        "#{api_url}#{path}",
        params,
        json: true,
        headers: headers,
        handle_errors: false
      )
    end

    handle_response(response)
  end

  def delete(path, id)
    response = with_rate_limit do
      Crest.delete(
        "#{api_url}#{path}/#{id}",
        json: true,
        headers: headers,
        handle_errors: false
      )
    end

    handle_response(response)
  end

  private def headers
    @headers ||= {
      "Authorization" => "Bearer #{token}",
    }
  end

  private def handle_rate_limit(response)
    local_reset_time = Time.local + 1.hour
    puts "[Hetzner API] Rate Limit hit. Rate limit resets at: #{local_reset_time.to_s("%Y-%m-%d %H:%M:%S")}"

    wait_time = 3600

    while wait_time > 0
      remaining = Time::Span.new(seconds: wait_time)
      puts "[Hetzner API] Waiting for #{remaining.total_hours.floor}h#{remaining.minutes.floor}m#{remaining.seconds.floor}s until rate limit reset..."
      sleep_time = [wait_time, 5].min
      sleep(sleep_time.seconds)
      wait_time -= sleep_time
    end
  end

  private def with_rate_limit
    while true
      response = yield

      if response.status_code == 429
        mutex.synchronize do
          handle_rate_limit(response)
        end
      else
        return response
      end
    end
  end

  private def handle_response(response) : Tuple(Bool, String)
    {response.success?, response.body.to_s}
  end
end
