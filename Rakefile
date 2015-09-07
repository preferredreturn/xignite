require 'rake'
require 'rspec/core'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = "./spec/**/*_spec.rb"
end

task :console do
  exec "irb -r xignite -I ./lib"
end

task :default => :spec