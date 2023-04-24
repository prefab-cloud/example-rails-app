class HomeController < ApplicationController
  def index
    logger.debug '🔍 Hello from Rails.logger.debug'
    logger.info  'ℹ️ Hello from Rails.logger.info'
    logger.warn  '⚠️ Hello from Rails.logger.warn'
    logger.error '🚨 Hello from Rails.logger.error'
  end

  def sign_in_as
    set_current_user(params[:user])
    redirect_to root_path
  end
end
