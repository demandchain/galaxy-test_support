require ::File.expand_path('capybara_diagnostics', File.dirname(__FILE__))
require ::File.expand_path('diagnostics_report_builder', File.dirname(__FILE__))
require ::File.expand_path('configuration', File.dirname(__FILE__))
require ::File.expand_path('log_capture', File.dirname(__FILE__))
require ::File.expand_path('configured_report', File.dirname(__FILE__))

After do |scenario|
  if scenario.failed?
    TestSupport::DiagnosticsReportBuilder.current_report.within_section("Error:") do |report|
      report_generator = TestSupport::Configuration.report_configuration(:cucumber)

      report_generator.add_report_objects(self: self, scenario: scenario)
      report_generator.generate_report_for_object(report, diagnostics_name: scenario.file_colon_line)
    end
  end
end

at_exit do
  TestSupport::DiagnosticsReportBuilder.current_report.close_report
end

TestSupport::DiagnosticsReportBuilder.new_report