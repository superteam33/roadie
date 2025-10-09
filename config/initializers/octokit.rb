# GitHub API client configuration
begin
  require 'octokit'
  
  Octokit.configure do |c|
    c.api_endpoint = 'https://api.github.com'
    c.web_endpoint = 'https://github.com'
    
    # Increase rate limit awareness
    c.auto_paginate = true
    c.per_page = 100
    
    # Connection options
    c.connection_options = {
      request: {
        open_timeout: 10,
        timeout: 30
      }
    }
  end

  # Middleware configuration
  Octokit.middleware = Faraday::RackBuilder.new do |builder|
    builder.use Faraday::Retry::Middleware, exceptions: [Octokit::ServerError]
    builder.use Octokit::Middleware::FollowRedirects
    builder.use Octokit::Response::RaiseError
    builder.adapter Faraday.default_adapter
  end
rescue LoadError
  Rails.logger.warn "Octokit gem not loaded. Install with: bundle install"
end

