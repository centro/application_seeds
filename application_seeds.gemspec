# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'application_seeds/version'

Gem::Specification.new do |gem|
  gem.name          = "application_seeds"
  gem.version       = ApplicationSeeds::VERSION
  gem.authors       = ["John Wood"]
  gem.email         = ["john.wood@centro.net"]
  gem.description   = %q{A library for managing standardized application seed data}
  gem.summary       = %q{A library for managing a standardized set of seed data for applications in a non-production environment}
  gem.homepage      = "https://github.com/centro/application_seeds"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "activesupport"
  gem.add_dependency "pg"

  gem.add_development_dependency "rspec"
  gem.add_development_dependency "rake"
end
