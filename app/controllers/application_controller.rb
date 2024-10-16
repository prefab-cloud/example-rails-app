class ApplicationController < ActionController::Base
  include Authentication

  around_action do |_, block|
    Prefab.with_context(prefab_context, &block)
  end

  def prefab_context
    {
      device: {
        mobile: mobile?
      },

      user: {
        key: current_user&.id,
        email: current_user&.email,
        country: current_user&.country,
      }
    }
  end

  def mobile?
    request.user_agent&.match?(/(iPhone|iPod|iPad|Android)/)
  end
end
