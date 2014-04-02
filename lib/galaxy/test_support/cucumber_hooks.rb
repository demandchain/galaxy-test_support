require ::File.expand_path('capybara_diagnostics', File.dirname(__FILE__))
require ::File.expand_path('diagnostics_report_builder', File.dirname(__FILE__))

After do |scenario|
  if scenario.failed?
    Galaxy::TestSupport::DiagnosticsReportBuilder.current_report.within_section("Error:") do |report|
      report.within_table do |report_table|
        if scenario.exception
          report_table.write_stats "Exception:", scenario.exception.to_s
          report_table.write_stats "Backtrace:", report.formatted_backtrace(scenario.exception)
        end

        vars_report = Galaxy::TestSupport::DiagnosticsReportBuilder::ReportTable.new
        scenario.instance_variable_names.each do |name|
          unless ["@background", "@feature", "@current_visitor", "@raw_steps"].include?(name)
            vars_report.write_stats name, Galaxy::TestSupport::DiagnosticsReportBuilder.pretty_print_variable(scenario.send(:instance_variable_get, name))
          end
        end
        self.instance_variable_names.each do |name|
          unless ["@__cucumber_runtime", "@__natural_language", "@_rack_test_sessions", "@_rack_mock_sessions",
                 "@integration_session"].include?(name)
            vars_report.write_stats name, Galaxy::TestSupport::DiagnosticsReportBuilder.pretty_print_variable(self.send(:instance_variable_get, name))
          end
        end
        report_table.write_stats "Instance Variables:", vars_report.full_table, prevent_shrink: true
      end
    end

    Galaxy::TestSupport::CapybaraDiagnostics.output_page_details(scenario.file_colon_line)
  end
end

at_exit do
  Galaxy::TestSupport::DiagnosticsReportBuilder.current_report.close_report
end

Galaxy::TestSupport::DiagnosticsReportBuilder.new_report