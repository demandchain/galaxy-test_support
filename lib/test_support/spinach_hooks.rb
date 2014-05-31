require ::File.expand_path('capybara_diagnostics', File.dirname(__FILE__))
require ::File.expand_path('diagnostics_report_builder', File.dirname(__FILE__))
require ::File.expand_path('configuration', File.dirname(__FILE__))
require ::File.expand_path('log_capture', File.dirname(__FILE__))
require ::File.expand_path('configured_report', File.dirname(__FILE__))

Spinach.hooks.before_scenario do |scenario, step_definitions|
  @running_scenario = scenario
end

Spinach.hooks.after_scenario do |scenario, step_definitions|
  @running_scenario = nil
end

Spinach.hooks.on_failed_step do |step_data, exception, location, step_definitions|
  debug_failed_step("Failure", step_data, exception, location, step_definitions)
end

Spinach.hooks.on_error_step do |step_data, exception, location, step_definitions|
  debug_failed_step("Error", step_data, exception, location, step_definitions)
end

def debug_failed_step(failure_description, step_data, exception, location, step_definitions)
  TestSupport::DiagnosticsReportBuilder.current_report.within_section("#{failure_description}:") do |report|
    report_generator = TestSupport::Configuration.report_configuration(:spinach)

    report_generator.add_report_objects(failure_description: "#{failure_description} at:, #{location[0]}:#{location[1]}",
                                        step_data:        step_data,
                                        exception:        exception,
                                        location:         location,
                                        step_definitions: step_definitions,
                                        running_scenario: @running_scenario
    )
    report_generator.generate_report_for_object(report, diagnostics_name: "#{step_data.name}:#{step_data.line}")
  end
end

Spinach.hooks.after_run do |status|
  TestSupport::DiagnosticsReportBuilder.current_report.close_report
end

TestSupport::DiagnosticsReportBuilder.new_report