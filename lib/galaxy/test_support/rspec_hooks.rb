require ::File.expand_path('capybara_diagnostics', File.dirname(__FILE__))
require ::File.expand_path('diagnostics_report_builder', File.dirname(__FILE__))

RSpec.configure do |config|
  config.before(:all) do
    Galaxy::TestSupport::DiagnosticsReportBuilder.new_report("diagnostics_rspec_report")
  end

  config.after(:all) do
    Galaxy::TestSupport::DiagnosticsReportBuilder.current_report("diagnostics_rspec_report").close_report
  end

  config.after(:each) do
    if (@example.exception)
      Galaxy::TestSupport::DiagnosticsReportBuilder.current_report("diagnostics_rspec_report").within_section("Error:") do |report|
        report.within_table do |report_table|
          if @example.exception
            report_table.write_stats "Exception:", @example.exception.to_s
            report_table.write_stats "Backtrace:", report.formatted_backtrace(@example.exception)
          end

          vars_report = Galaxy::TestSupport::DiagnosticsReportBuilder::ReportTable.new
          @example.instance_variable_names.each do |name|
            vars_report.write_stats name, @example.send(:instance_variable_get, name).pretty_inspect
          end
          report_table.write_stats "Instance Variables:", vars_report.full_table
        end
      end

      Galaxy::TestSupport::CapybaraDiagnostics.output_page_details(@example.full_description)
    end
  end
end