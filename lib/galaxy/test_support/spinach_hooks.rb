require ::File.expand_path('capybara_diagnostics', File.dirname(__FILE__))
require ::File.expand_path('diagnostics_report_builder', File.dirname(__FILE__))

Spinach.hooks.on_failed_step do |step_data, exception, location, step_definitions|
  debug_failed_step("Failure", step_data, exception, location, step_definitions)
end

Spinach.hooks.on_error_step do |step_data, exception, location, step_definitions|
  debug_failed_step("Error", step_data, exception, location, step_definitions)
end

def debug_failed_step(failure_description, step_data, exception, location, step_definitions)
  Galaxy::TestSupport::DiagnosticsReportBuilder.current_report.within_section("#{failure_description}:") do |report|
    report.within_table do |report_table|
      report_table.write_stats "#{failure_description} at:", "#{location[0]}:#{location[1]}"
      report_table.write_stats "Scenario:", step_data.scenario if step_data.scenario
      report_table.write_stats "Line:", "#{step_data.name}:#{step_data.line}"
      report_table.write_stats "Exception:", exception.to_s
      report_table.write_stats "Backtrace:", report.formatted_backtrace(exception)

      vars_report = Galaxy::TestSupport::DiagnosticsReportBuilder::ReportTable.new
      step_definitions.instance_variable_names.each do |name|
        vars_report.write_stats name, step_definitions.send(:instance_variable_get, name).pretty_inspect
      end
      report_table.write_stats "Instance Variables:", vars_report.full_table
    end
  end

  Galaxy::TestSupport::CapybaraDiagnostics.output_page_details("#{step_data.name}:#{step_data.line}")
end

Spinach.hooks.after_run do |status|
  Galaxy::TestSupport::DiagnosticsReportBuilder.current_report.close_report
end

Galaxy::TestSupport::DiagnosticsReportBuilder.new_report