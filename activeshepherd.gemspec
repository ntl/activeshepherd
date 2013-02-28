# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'active_shepherd/version'

Gem::Specification.new do |gem|
  gem.name          = "activeshepherd"
  gem.version       = ActiveShepherd::VERSION
  gem.authors       = ["ntl"]
  gem.email         = ["nathanladd+github@gmail.com"]
  gem.description   = %q{Wrangle unweildy app/models directories by unobtrusively adding the aggregate pattern into ActiveRecord}
  gem.summary       = %q{Wrangle unweildy app/models directories with aggregates}
  gem.homepage      = "http://github.com/ntl/eat_my_babies"
  gem.license       = "MIT"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}) { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "activerecord", ">= 2.3.17"

  gem.add_development_dependency "activerecord", "4.0.0.beta1"
  gem.add_development_dependency "guard"
  gem.add_development_dependency "guard-minitest"
  gem.add_development_dependency "hashie"
  gem.add_development_dependency "minitest-reporters"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "rb-fsevent"
  gem.add_development_dependency "sqlite3"
end
