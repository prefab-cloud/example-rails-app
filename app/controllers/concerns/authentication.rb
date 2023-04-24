module Authentication
  extend ActiveSupport::Concern

  DEMO_USERS = [
    { country: 'UK', name: 'Tony', email: 'tony@example.com', id: 1 },
    { country: 'FR', name: 'Joan', email: 'joan@example.com', id: 2 },
    { country: 'US', name: 'Jeff', email: 'jeff.dwyer@prefab.cloud', id: 3 }
  ].freeze

  included do
    before_action :set_default_demo_cookie

    def set_default_demo_cookie
      current_user || set_current_user(DEMO_USERS[0].to_json)
    end

    def set_current_user(new_current_user)
      cookies[:current_user] = {
        value: new_current_user,
        secure: Rails.env.production?
      }
    end

    def current_user
      return nil unless cookies[:current_user]

      OpenStruct.new(JSON.parse(cookies[:current_user]))
    end
    helper_method :current_user
  end
end
