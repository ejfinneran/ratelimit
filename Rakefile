# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "ratelimit"
  gem.homepage = "http://github.com/ejfinneran/ratelimit"
  gem.license = "MIT"
  gem.summary = %Q{TODO: one-line summary of your gem}
  gem.description = %Q{TODO: longer description of your gem}
  gem.email = "ej.finneran@gmail.com"
  gem.authors = ["E.J. Finneran"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.test_files = FileList['test/**/test_*.rb']
  test.verbose = true
end

task :default => :test

namespace :doc do
  project_root = File.dirname(__FILE__)
  doc_destination = File.join(project_root, 'rdoc')

  begin
    require 'rdoc'
    require 'yard'
    require 'yard/rake/yardoc_task'

    YARD::Rake::YardocTask.new(:generate) do |yt|
    yt.files   = Dir.glob(File.join(project_root, 'lib', '**', '*.rb')) 
    yt.options = ['--output-dir', doc_destination, '--readme', 'README.md']
  end
  rescue LoadError
    desc "Generate YARD Documentation"
    task :generate do
      abort "Please install the YARD gem to generate rdoc."
    end
  end

  desc "Remove generated documenation"
  task :clean do
    rm_r doc_dir if File.exists?(doc_destination)
  end

end
