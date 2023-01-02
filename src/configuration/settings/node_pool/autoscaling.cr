require "../../node_pool"

class Configuration::Settings::NodePool::Autoscaling
  getter errors : Array(String)
  getter pool : Configuration::NodePool

  def initialize(@errors, @pool)
  end

  def validate
    autoscaling_settings = pool.try(&.autoscaling)

    if autoscaling_settings && autoscaling_settings.enabled
      errors << "Autoscaling settings for pool #{pool.name} are invalid: max_instances must be greater than min_instances" if autoscaling_settings.max_instances <= autoscaling_settings.min_instances
    end
  end
end
