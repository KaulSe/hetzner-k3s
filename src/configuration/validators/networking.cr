require "../../hetzner/client"
require "../models/networking"
require "../models/networking_config/cni"
require "../models/networking_config/allowed_networks"
require "../models/networking_config/private_network"
require "../models/networking_config/public_network"
require "../models/networking_config/ssh"
require "./networking_config/cni"
require "./networking_config/allowed_networks"
require "./networking_config/private_network"
require "./networking_config/public_network"
require "./networking_config/ssh"

class Configuration::Validators::Networking
  getter errors : Array(String)
  getter networking : Configuration::Models::Networking
  getter settings : Configuration::Main
  getter hetzner_client : Hetzner::Client
  getter private_network : Configuration::Models::NetworkingConfig::PrivateNetwork

  def initialize(@errors, @networking, @settings, @hetzner_client, @private_network)
  end

  def validate
    Configuration::Validators::NetworkingConfig::CNI.new(errors, networking.cni, private_network).validate
    Configuration::Validators::NetworkingConfig::AllowedNetworks.new(errors, networking.allowed_networks).validate
    Configuration::Validators::NetworkingConfig::PrivateNetwork.new(errors, private_network, hetzner_client).validate
    Configuration::Validators::NetworkingConfig::PublicNetwork.new(errors, networking.public_network, settings).validate
    Configuration::Validators::NetworkingConfig::SSH.new(errors, networking.ssh, hetzner_client, settings.cluster_name).validate
  end
end