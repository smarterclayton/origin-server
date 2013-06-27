class Rake::Task
  def abandon
    prerequisites.clear
    @actions.clear
  end
end

namespace :test do
  console_path = Console::Engine.root

  Rake::TestTask.new :console do |i|
    i.test_files = FileList["#{console_path}/test/**/*_test.rb"]
  end
  task :console => 'test:console:prepare'

  namespace :console do

  namespace :prepare do
    task :ci_reporter do
      # define our own ci_reporter task to NOT delete test reports (can't run in parallel if we're deleting)
      begin 
        require 'ci/reporter/rake/minitest'
        path = File.join(Gem.loaded_specs["ci_reporter"].full_gem_path, 'lib', 'ci', 'reporter', 'rake', 'minitest_loader.rb')
        test_loader = CI::Reporter.maybe_quote_filename path
        ENV["TESTOPTS"] = "#{ENV["TESTOPTS"]} #{test_loader}"
      rescue Exception
        # ci_reporter is optional in the gemfile
      end
    end
  end
  task :prepare => 'test:console:prepare:ci_reporter'

  ['unit', 'functional', 'integration'].each do |s|
    Rake::TestTask.new s.to_sym => 'test:prepare' do |t|
      t.libs << 'test'
      t.test_files = FileList[
        "#{console_path}/test/#{s}/**/*_test.rb",
      ]
    end
  end

  Rake::TestTask.new :restapi => 'test:prepare' do |t|
    t.libs << 'test'
    t.test_files = FileList[
      "#{console_path}/**/rest_api_test.rb",
      "#{console_path}/**/rest_api/*_test.rb",
    ]
  end

  namespace :check do
    covered = []

    Rake::TestTask.new :applications => ['test:prepare'] do |t|
      t.libs << 'test'
      covered.concat(t.test_files = FileList[
        "#{console_path}/functional/applications_controller_sanity_test.rb",
      ])
    end

    Rake::TestTask.new :cartridges => ['test:prepare'] do |t|
      t.libs << 'test'
      covered.concat(t.test_files = FileList[
        "#{console_path}/functional/cartridges_controller_test.rb",
        "#{console_path}/functional/cartridge_types_controller_test.rb",
      ])
    end

    Rake::TestTask.new :misc1 => ['test:prepare'] do |t|
      t.libs << 'test'
      covered.concat(t.test_files = FileList[
        "#{console_path}/functional/applications_controller_test.rb",
        "#{console_path}/functional/application_types_controller_test.rb",
        "#{console_path}/functional/domains_controller_test.rb",
        "#{console_path}/functional/scaling_controller_test.rb",
        "#{console_path}/integration/rest_api/cartridge_test.rb",
      ])
    end

    Rake::TestTask.new :restapi_integration => ['test:prepare'] do |t|
      t.libs << 'test'
      covered.concat(t.test_files = FileList[
        "#{console_path}/integration/rest_api/**_test.rb",
      ].exclude("#{console_path}/integration/rest_api/cartridge_test.rb"))
    end

    Rake::TestTask.new :base => ['test:prepare'] do |t|
      t.libs << 'test'
      t.test_files = FileList["#{console_path}/**/*_test.rb"] - covered
    end
  end
  task :check => Rake::Task.tasks.select{ |t| t.name.match(/\Atest:console:check:/) }.map(&:name)
  task :extended => []
  end
end
