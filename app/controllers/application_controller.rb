class ApplicationController < ActionController::Base
  protect_from_forgery

  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper :all

  def redirect_back(fallback_path, *args)
    redirect_to :back, *args
  rescue ActionController::RedirectBackError
    redirect_to fallback_path, *args
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.for(:sign_up) { |u| u.permit(:username, :email, :password, :password_confirmation, :remember_me, :invitation_code) }
    devise_parameter_sanitizer.for(:sign_in) { |u| u.permit(:login, :username, :email, :password, :remember_me) }
    devise_parameter_sanitizer.for(:account_update) { |u| u.permit(:username, :email, :password, :password_confirmation, :current_password) }
  end

  def authenticate_admin!
    redirect_to(root_path, alert: 'Admin access required to view that page.') unless current_user && current_user.admin?
  end

  def upgrade_warning
    return unless current_user
    twitter_oauth_check
    basecamp_auth_check
  end

  def filtered_agent_return_link(options = {})
    case ret = params[:return].presence || options[:return]
      when "show"
        if @agent && !@agent.destroyed?
          agent_path(@agent)
        else
          agents_path
        end
      when /\A#{(Regexp::escape scenarios_path)}/, /\A#{(Regexp::escape agents_path)}/, /\A#{(Regexp::escape events_path)}/
        ret
    end
  end
  helper_method :filtered_agent_return_link

  private

  def twitter_oauth_check
    unless Devise.omniauth_providers.include?(:twitter)
      if @twitter_agent = current_user.agents.where("type like 'Agents::Twitter%'").first
        @twitter_oauth_key    = @twitter_agent.options['consumer_key'].presence || @twitter_agent.credential('twitter_consumer_key')
        @twitter_oauth_secret = @twitter_agent.options['consumer_secret'].presence || @twitter_agent.credential('twitter_consumer_secret')
      end
    end
  end

  def basecamp_auth_check
    unless Devise.omniauth_providers.include?(:'37signals')
      @basecamp_agent = current_user.agents.where(type: 'Agents::BasecampAgent').first
    end
  end

  def agent_params
    return {} unless params[:agent]
    @agent_params ||= begin
      options = params[:agent].delete(:options) if params[:agent][:options].present?
      params[:agent].permit(:memory, :name, :type, :schedule, :disabled, :keep_events_for, :propagate_immediately, :drop_pending_events,
                            source_ids: [], receiver_ids: [], scenario_ids: [], controller_ids: [], control_target_ids: []).tap do |agent_params|
        agent_params[:options] = options if options
      end
    end
  end
end
