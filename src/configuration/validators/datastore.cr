require "../models/datastore"
require "../validators/datastore_config/etcd"

class Configuration::Validators::Datastore
  getter errors : Array(String)
  getter datastore : Configuration::Models::Datastore

  def initialize(@errors, @datastore)
  end

  def validate
    return errors << "datastore mode is invalid - allowed values are 'etcd' and 'external'" unless {"etcd", "external"}.includes?(datastore.mode)
    return unless datastore.mode == "external"

    errors << "external_datastore_endpoint is required for external datastore" if datastore.external_datastore_endpoint.strip.empty?
    
    etcd_validator = Configuration::Validators::DatastoreConfig::Etcd.new(errors, datastore.etcd)
    etcd_validator.validate_s3_settings if datastore.mode == "etcd"
    etcd_validator.validate_etcd_settings if datastore.mode == "etcd"
  end
end