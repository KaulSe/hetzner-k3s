require "yaml"

require "./node_label"
require "./node_taint"
require "./autoscaling"

abstract class Configuration::NodePool
  include YAML::Serializable

  property name : String?
  property legacy_instance_type : String = ""
  property instance_type : String
  property image : String | Int64 | Nil
  property instance_count : Int32 = 1
  property labels : Array(::Configuration::NodeLabel) = [] of ::Configuration::NodeLabel
  property taints : Array(::Configuration::NodeTaint) = [] of ::Configuration::NodeTaint
  property autoscaling : ::Configuration::Autoscaling?
  property additional_pre_k3s_commands : Array(String) | Nil
  property additional_post_k3s_commands : Array(String) | Nil
  property additional_packages : Array(String) | Nil
  property include_cluster_name_as_prefix : Bool = true

  getter autoscaling_enabled : Bool do
    autoscaling.try(&.enabled) || false
  end
end
