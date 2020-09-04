require "bundler/gem_tasks"

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
