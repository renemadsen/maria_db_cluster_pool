# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{maria_db_cluster_pool}
  s.version = "0.0.8"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Ren\303\251 Schultz Madsen"]
  s.date = Date.today.to_s
  s.description = %q{This gem add support for the Maria DB Galera Cluster setup.}
  s.email = %q{rm@microting.com}
  s.license = 'MIT'
  s.extra_rdoc_files = [
    "MIT-LICENSE",
    "README.md"
  ]
  s.files = [
    "MIT-LICENSE",
    "README.md",
    "Rakefile",
    "lib/active_record/connection_adapters/maria_db_cluster_pool_adapter.rb",
    "lib/maria_db_cluster_pool.rb",
    "lib/maria_db_cluster_pool/arel_compiler.rb",
    "lib/maria_db_cluster_pool/connect_timeout.rb"
  ]
  s.homepage = %q{https://github.com/renemadsen/maria_db_cluster_pool}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.5.3}
  s.summary = %q{Add support for master/master database clusters in ActiveRecord to improve performance.}

  s.add_dependency(%q<activerecord>, [">= 2.3.11"])
  s.add_dependency(%q<rake>, [">= 0.8.7"])
  # s.add_dependency(%q<mysql>, [">= 0"])
  s.add_development_dependency(%q<rspec>, [">= 0"])
end

