class AppBranding
  DEFAULTS = {
    "app_name" => "Bagel OS",
    "short_name" => "Bagel OS",
    "description" => "Restaurant inventory, purchasing, order-guide, and price intelligence."
  }.freeze

  def self.current
    new(DEFAULTS.merge(private_config))
  end

  attr_reader :app_name, :short_name, :description

  def initialize(values)
    @app_name = values.fetch("app_name")
    @short_name = values.fetch("short_name")
    @description = values.fetch("description")
  end

  def self.config_path
    Rails.root.join(".private", "branding.yml")
  end

  def self.private_config
    return {} unless config_path.exist?

    YAML.safe_load(config_path.read) || {}
  rescue Psych::Exception
    Rails.logger.warn("Ignoring invalid private branding config at #{config_path}")
    {}
  end

  private_class_method :private_config
end
