require "../../configuration/loader"
require "../../configuration/main"
require "../../hetzner/server"
require "../../hetzner/server/create"
require "../../util"
require "../../util/shell"
require "../../util/ssh"
require "../resources/resource"
require "../resources/deployment"
require "../resources/pod/spec/toleration"
require "../resources/pod/spec/container"

class Kubernetes::Software::ClusterAutoscaler
  getter configuration : Configuration::Loader
  getter settings : Configuration::Main { configuration.settings }
  getter autoscaling_worker_node_pools : Array(Configuration::NodePool)
  getter worker_install_script : String
  getter first_master : ::Hetzner::Server
  getter ssh : Util::SSH

  def initialize(@configuration, @settings, @first_master, @ssh, @autoscaling_worker_node_pools, @worker_install_script)
  end

  def install
    puts "\n[Cluster Autoscaler] Installing Cluster Autoscaler..."

    command = <<-BASH
    kubectl apply -f - <<-EOF
    #{manifest}
    EOF
    BASH

    run_command command

    puts "[Cluster Autoscaler] ...Cluster Autoscaler installed"
  end

  private def cloud_init
    ::Hetzner::Server::Create.cloud_init(settings.ssh_port, settings.snapshot_os, settings.additional_packages, settings.post_create_commands, [k3s_join_script])
  end

  private def k3s_join_script
    "|\n    #{worker_install_script.gsub("\n", "\n    ")}"
  end

  private def certificate_path
    @certificate_path ||= if ssh.run(first_master, settings.ssh_port, "[ -f /etc/ssl/certs/ca-certificates.crt ] && echo 1 || echo 2", settings.use_ssh_agent, false).chomp == "1"
      "/etc/ssl/certs/ca-certificates.crt"
    else
      "/etc/ssl/certs/ca-bundle.crt"
    end
  end

  private def node_pool_args
    autoscaling_worker_node_pools.map do |pool|
      autoscaling = pool.autoscaling.not_nil!
      "- --nodes=#{autoscaling.min_instances}:#{autoscaling.max_instances}:#{pool.instance_type.upcase}:#{pool.location.upcase}:#{pool.name}"
    end
  end

  private def fetch_manifest
    response = Crest.get(settings.cluster_autoscaler_manifest_url)

    unless response.success?
      puts "[Cluster Autoscaler] Failed to download Cluster Autoscaler manifest from #{settings.cluster_autoscaler_manifest_url}"
      puts "[Cluster Autoscaler] Server responded with status #{response.status_code}"
      exit 1
    end

    response.body.to_s
  end

  private def patch_resources(resources)
    resources.map do |resource|
      resource = Kubernetes::Resources::Resource.from_yaml(resource.to_yaml)

      if resource.kind == "Deployment"
        patched_deployment(resource)
      else
        resource
      end
    end
  end

  private def patched_deployment(resource)
    deployment = Kubernetes::Resources::Deployment.from_yaml(resource.to_yaml)

    patch_tolerations(deployment.spec.template.spec)
    patch_containers(deployment.spec.template.spec.containers)
    patch_volumes(deployment.spec.template.spec.volumes)

    deployment
  end

  private def run_command(command)
    result = Util::Shell.run(command, configuration.kubeconfig_path, settings.hetzner_token, prefix: "Cluster Autoscaler")

    unless result.success?
      puts "[Cluster Autoscaler] Failed to install the Cluster Autoscaler:"
      puts result.output
      exit 1
    end
  end

  private def patch_tolerations(spec)
    toleration = Kubernetes::Resources::Pod::Spec::Toleration.new(effect: "NoExecute", key: "CriticalAddonsOnly", value: "true")

    if tolerations = spec.tolerations
      tolerations << toleration
    else
      spec.tolerations = [toleration]
    end
  end

  private def container_command
    command = [
      "- ./cluster-autoscaler",
      "-cloud-provider=hetzner",
      "-enforce-node-group-min-size",
    ]

    container_command = command += node_pool_args
    container_command.join("\m")
  end

  private def patch_autoscaler_container(autoscaler_container)
    autoscaler_container.command = container_command

    set_container_environment_variable(autoscaler_container, "HCLOUD_CLOUD_INIT", Base64.strict_encode(cloud_init))
    set_container_environment_variable(autoscaler_container, "HCLOUD_IMAGE", settings.autoscaling_image || settings.image)
    set_container_environment_variable(autoscaler_container, "HCLOUD_FIREWALL", settings.cluster_name)
    set_container_environment_variable(autoscaler_container, "HCLOUD_SSH_KEY", settings.cluster_name)
    set_container_environment_variable(autoscaler_container, "HCLOUD_NETWORK", (settings.existing_network || settings.cluster_name))

    set_certificate_path(autoscaler_container)
  end

  private def set_container_environment_variable(autoscaler_container, variable_name, variable_value)
    env_variables = autoscaler_container.env

    return if env_variables.nil?

    if variable = env_variables.find { |env| env.name == variable_name }
      variable.value = variable_value
    else
      env_variables << Kubernetes::Resources::Pod::Spec::Container::EnvVariable.new(name: variable_name, value: variable_value)
    end
  end

  private def set_certificate_path(autoscaler_container)
    volume_mounts = autoscaler_container.volumeMounts

    return unless volume_mounts

    if volume_mount = volume_mounts.find { |volume_mount| volume_mount.name == "ssl-certs" }
      volume_mount.mountPath = certificate_path
    end
  end

  private def patch_containers(containers)
    return unless containers

    if autoscaler_container = containers.find { |container| container.name == "cluster-autoscaler" }
      patch_autoscaler_container(autoscaler_container)
    end
  end

  private def patch_volumes(volumes)
    return unless volumes

    certificate_volume = volumes.find { |volume| volume.name == "ssl-certs" }

    return unless certificate_volume

    if host_path = certificate_volume.hostPath
      host_path.path = certificate_path
    end
  end

  private def manifest
    manifest = fetch_manifest
    resources = YAML.parse_all(manifest)
    patched_resources = patch_resources(resources)
    patched_resources.map(&.to_yaml).join
  end
end
