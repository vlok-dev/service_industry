class UsernameSessionMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    username = extract_username(env)
    if username
      key = "_industro_plumbers_#{username}_session"
      if env["action_dispatch.session.options"]
        env["action_dispatch.session.options"][:key] = key
      end
    end
    @app.call(env)
  end

  private

  def extract_username(env)
    path = env["PATH_INFO"] || ""
    match = path.match(%r{^/([^/]+)})
    username = match ? match[1] : nil
    return nil unless username && username.match?(/\A[a-z_]+\z/)

    username
  end
end