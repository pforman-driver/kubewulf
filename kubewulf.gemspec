
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "kubewulf/version"

Gem::Specification.new do |spec|
  spec.name          = "kubewulf"
  spec.version       = Kubewulf::VERSION
  spec.authors       = ["Range Strunk"]
  spec.email         = ["rangedev@gmail.com"]

  spec.summary       = %q{Opinionated hierarchical data, used for configuring kubernetes clusters.}
  spec.homepage      = "https://github.com/rangedev/kubewulf"
  spec.license       = 'Apache-2.0'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "deep_merge", "~> 1.1.1"
  spec.add_development_dependency "rest-client", "~> 2.0.2"
  spec.add_development_dependency "kubeclient", "~> 2.5.1"
  spec.add_development_dependency "vault", "~> 0.10"

  spec.add_runtime_dependency "deep_merge", "~> 1.1.1"
  spec.add_runtime_dependency "rest-client", "~> 2.0.2"
  spec.add_runtime_dependency "kubeclient", "~> 2.5.1"
  spec.add_runtime_dependency "vault", "~> 0.10"
end
