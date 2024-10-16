require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ExampleApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    Prefab.init

    Prefab.instance.on_update do
      if defined?(Turbo::StreamsChannel)
        Turbo::StreamsChannel.broadcast_replace_to :prefab_values,
                                                   target: 'prefab-values',
                                                   partial: 'home/prefab_values'
      end
    end
  end
end
