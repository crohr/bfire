require 'rake'
require 'rspec/core/rake_task'

ROOT_DIR = File.dirname(__FILE__)

desc "Run Tests"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rcov = false
  t.pattern = 'spec/**/*_spec.rb'
end

desc "Run Test coverage"
RSpec::Core::RakeTask.new(:rcov) do |t|
  t.rcov = true
  t.pattern = 'spec/**/*_spec.rb'
  t.rcov_opts = ['-Ispec', '--exclude', 'spec']
end

task :default => :spec

task :clean do
  Dir.chdir(ROOT_DIR) do
    rm_f "*.gem"
  end
end

task :build => :clean do
  Dir.chdir(ROOT_DIR) do
    sh "gem build bfire.gemspec"
  end
end

task :install => :build do
  Dir.chdir(ROOT_DIR) do
    sh "gem install #{Dir["*.gem"].last}"
  end
end
