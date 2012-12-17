# -*- encoding: utf-8 -*-
require File.dirname(__FILE__) + '/lib/omniauth-streamline/version'

Gem::Specification.new do |gem|
  gem.add_runtime_dependency 'omniauth', '~> 1.0'

  gem.add_development_dependency 'rack-test', '~> 0.5'
  gem.add_development_dependency 'rake', '~> 0.8'
  gem.add_development_dependency 'rspec', '~> 2.7'

  gem.name = 'omniauth-streamline'
  gem.version = OmniAuth::Streamline::VERSION
  gem.description = %q{Streamline authentication handlers for OmniAuth.}
  gem.summary = gem.description
  gem.email = ['ccoleman@redhat.com']
  gem.homepage = 'http://github.com/openshift/origin-server/tree/master/plugins/auth/omniauth-streamline'
  gem.authors = ['Clayton Coleman']
  gem.executables = `git ls-files -- bin/*`.split("\n").map{|f| File.basename(f)}
  gem.files = `git ls-files`.split("\n")
  gem.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.require_paths = ['lib']
  gem.required_rubygems_version = Gem::Requirement.new('>= 1.3.6') if gem.respond_to? :required_rubygems_version=
end
