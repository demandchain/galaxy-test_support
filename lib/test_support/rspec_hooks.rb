require ::File.expand_path('capybara_diagnostics', File.dirname(__FILE__))
require ::File.expand_path('diagnostics_report_builder', File.dirname(__FILE__))
require ::File.expand_path('configuration', File.dirname(__FILE__))
require ::File.expand_path('log_capture', File.dirname(__FILE__))
require ::File.expand_path('configured_report', File.dirname(__FILE__))

RSpec.configure do |config|
  config.before(:suite) do
    TestSupport::DiagnosticsReportBuilder.new_report("diagnostics_rspec_report")
  end

  config.after(:suite) do
    TestSupport::DiagnosticsReportBuilder.current_report("diagnostics_rspec_report").close_report
  end

  config.before(:each) do |example|
    @seed_value = TestSupport::Configuration.rspec_seed ||
        100000000000000000000000000000000000000 + rand(899999999999999999999999999999999999999)

    srand(@seed_value)
  end

  config.after(:each) do |example|
    if (example.exception)
      TestSupport::DiagnosticsReportBuilder.current_report("diagnostics_rspec_report").within_section("Error:") do |report|
        report_generator = TestSupport::Configuration.report_configuration(:rspec)

        report_generator.add_report_objects(self: self)
        report_generator.generate_report_for_object(report, diagnostics_name: example.full_description)
      end

      puts ("random seed for testing was: #{@seed_value}")
    end
  end
end