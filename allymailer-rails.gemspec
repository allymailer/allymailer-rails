# frozen_string_literal: true

require_relative 'lib/allymailer/wrapper/version'

Gem::Specification.new do |spec|
  spec.name = 'allymailer-rails'
  spec.version = AllyMailer::Wrapper::VERSION
  spec.summary = 'AllyMailer Web API for Rails: API client, Action Mailer delivery method, webhooks'
  spec.authors = ['AllyMailer']
  spec.license = 'MIT'
  spec.homepage = 'https://github.com/allymailer/allymailer-rails'
  spec.metadata = { 'documentation_uri' => 'https://docs.allymailer.com.ua/ua/web-api-ref' }
  spec.required_ruby_version = '>= 2.7'
  spec.files = Dir['lib/**/*.rb', 'README.md', 'AGENTS.md', 'LICENSE']
  spec.require_paths = ['lib']
  spec.add_dependency 'allymailer-ruby-sdk', '>= 1.1.2'
  spec.add_dependency 'actionmailer', '>= 6.1'
  spec.add_dependency 'actionpack', '>= 6.1'
  spec.add_dependency 'railties', '>= 6.1'
end
