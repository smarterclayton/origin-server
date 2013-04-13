if defined? Capybara
  require 'capybara/rails'
  require 'capybara/poltergeist'
  Capybara.register_driver :poltergeist do |app|
    Capybara::Poltergeist::Driver.new(app, :debug => !!ENV['CAPYBARA_DEBUG'])
  end
  Capybara.javascript_driver = :poltergeist

  class ActionDispatch::IntegrationTest
    include Capybara::DSL
    def self.web_integration
      setup{ Capybara.current_driver = Capybara.javascript_driver }
      teardown{ save_screenshot("#{ENV['TEST_SCREENSHOT_DIR']}#{"#{self.class}#{name}".parameterize}_#{DateTime.now.strftime("%Y%m%d%H%M%S%L")}.png") unless passed? }
    end
  end
end