require ::File.expand_path('capybara_diagnostics', File.dirname(__FILE__))
require ::File.expand_path('diagnostics_report_builder', File.dirname(__FILE__))

RSpec.configure do |config|
  config.before(:suite) do
    Galaxy::TestSupport::DiagnosticsReportBuilder.new_report("diagnostics_rspec_report")
  end

  config.after(:suite) do
    Galaxy::TestSupport::DiagnosticsReportBuilder.current_report("diagnostics_rspec_report").close_report
  end

  config.around(:each) do |example|
    @seed_value = rand(100000000000000000000000000000000000000..999999999999999999999999999999999999999)
    srand(@seed_value)

    example.run

    if (@example.exception)
      puts ("random seed for testing was: #{@seed_value}")
    end
  end

  config.after(:each) do
    if (@example.exception)
      Galaxy::TestSupport::DiagnosticsReportBuilder.current_report("diagnostics_rspec_report").within_section("Error:") do |report|
        report.within_table do |report_table|
          [:full_description, :location].each do |property|
            report_table.write_stats "#{property.to_s.humanize}:", @example.send(property)
          end
          report_table.write_stats "Call stack:", report.formatted_trace(@example.metadata[:caller])

          if @example.exception
            report_table.write_stats "Exception:", @example.exception.to_s
            report_table.write_stats "Backtrace:", report.formatted_backtrace(@example.exception)
          end

          report_table.write_stats "Random Seed:", @seed_value.to_s

          vars_report = Galaxy::TestSupport::DiagnosticsReportBuilder::ReportTable.new
          @example.instance_variable_names.each do |name|
            unless ["@example_group_instance", "@metadata"].include? name
              vars_report.write_stats name, @example.instance_variable_get(name.to_sym).pretty_inspect
            end
          end
          report_table.write_stats "Instance Variables:", vars_report.full_table
        end
      end

      Galaxy::TestSupport::CapybaraDiagnostics.output_page_details(@example.full_description)
    end
  end
end