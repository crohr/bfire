# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'bfire/version'

Gem::Specification.new do |s|
  s.name                      = "bfire"
  s.version                   = Bfire::VERSION
  s.platform                  = Gem::Platform::RUBY
  s.required_ruby_version     = '>= 1.8'
  s.required_rubygems_version = ">= 1.3"
  s.authors                   = ["Cyril Rohr"]
  s.email                     = ["cyril.rohr@inria.fr"]
  s.executables               = ["bfire"]
  s.homepage                  = "http://github.com/crohr/bfire"
  s.summary                   = "Launch experiments on BonFIRE"
  s.description               = "Launch experiments on BonFIRE"

  s.add_dependency('restfully')
  s.add_dependency('libxml-ruby')
  s.add_dependency('backports')
  s.add_dependency('net-ssh-gateway')
  s.add_dependency('rgl')
  s.add_dependency('uuidtools')
  

  s.add_development_dependency('rake', '~> 0.8')
  s.add_development_dependency('rspec', '~> 2')
  s.add_development_dependency('webmock')
  s.add_development_dependency('autotest')
  s.add_development_dependency('autotest-growl')

  s.files = Dir.glob("{bin,lib,spec,examples}/**/*") + %w(Rakefile LICENSE README.md)

  s.test_files = Dir.glob("spec/**/*")

  s.rdoc_options = ["--charset=UTF-8"]
  s.extra_rdoc_files = [
    "LICENSE",
    "README.md"
  ]

  s.require_path = 'lib'
end
