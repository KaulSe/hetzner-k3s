require "yaml"

require "./master_node_pool"
require "./worker_node_pool"
require "./datastore"
require "./manifests"
require "./embedded_registry_mirror"
require "./local_path_storage_class"
require "./csi_driver"
require "./traefik"
require "./servicelb"
require "./metrics_server"
require "./cluster_autoscaler"

class Configuration::Main
  include YAML::Serializable

  getter hetzner_token : String = ENV.fetch("HCLOUD_TOKEN", "")
  getter cluster_name : String
  getter kubeconfig_path : String
  getter k3s_version : String
  getter api_server_hostname : String?
  getter schedule_workloads_on_masters : Bool = false
  getter masters_pool : Configuration::MasterNodePool
  getter worker_node_pools : Array(Configuration::WorkerNodePool) = [] of Configuration::WorkerNodePool
  getter additional_pre_k3s_commands : Array(String) = [] of String
  getter additional_post_k3s_commands : Array(String) = [] of String
  getter additional_packages : Array(String) = [] of String
  getter kube_api_server_args : Array(String) = [] of String
  getter kube_scheduler_args : Array(String) = [] of String
  getter kube_controller_manager_args : Array(String) = [] of String
  getter kube_cloud_controller_manager_args : Array(String) = [] of String
  getter cluster_autoscaler_args : Array(String) = [] of String
  getter kubelet_args : Array(String) = [] of String
  getter kube_proxy_args : Array(String) = [] of String
  getter image : String = "ubuntu-24.04"
  getter autoscaling_image : String?
  getter snapshot_os : String = "default"
  getter networking : Configuration::Networking = Configuration::Networking.new
  getter datastore : Configuration::Datastore = Configuration::Datastore.new
  getter manifests : Configuration::Manifests = Configuration::Manifests.new
  getter embedded_registry_mirror : Configuration::EmbeddedRegistryMirror = Configuration::EmbeddedRegistryMirror.new
  getter local_path_storage_class : Configuration::LocalPathStorageClass = Configuration::LocalPathStorageClass.new
  getter csi_driver : Configuration::CSIDriver = Configuration::CSIDriver.new
  getter traefik : Configuration::Traefik = Configuration::Traefik.new
  getter servicelb : Configuration::ServiceLB = Configuration::ServiceLB.new
  getter metrics_server : Configuration::MetricsServer = Configuration::MetricsServer.new
  getter cluster_autoscaler : Configuration::ClusterAutoscaler = Configuration::ClusterAutoscaler.new
  getter include_instance_type_in_instance_name : Bool = false
  getter protect_against_deletion : Bool = true
  getter create_load_balancer_for_the_kubernetes_api : Bool = false
  getter k3s_upgrade_concurrency : Int64 = 1

  def all_kubelet_args
    ["cloud-provider=external", "resolv-conf=/etc/k8s-resolv.conf"] + kubelet_args
  end
end
