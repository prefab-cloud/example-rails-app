class ApplicationController < ActionController::Base
  around_action do |_, block|
    $prefab.with_context(prefab_context, &block)
  end

  def prefab_context
    {
      device: {
        mobile: mobile?
      }
    }
  end

  def mobile?
    request.user_agent&.match?(/(iPhone|iPod|iPad|Android)/)
  end
end
