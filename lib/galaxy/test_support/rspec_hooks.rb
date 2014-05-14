require ::File.expand_path('capybara_diagnostics', File.dirname(__FILE__))
require ::File.expand_path('diagnostics_report_builder', File.dirname(__FILE__))
require ::File.expand_path('configuration', File.dirname(__FILE__))
require ::File.expand_path('log_capture', File.dirname(__FILE__))

RSpec.configure do |config|
  config.before(:suite) do
    Galaxy::TestSupport::DiagnosticsReportBuilder.new_report("diagnostics_rspec_report")
  end

  config.after(:suite) do
    Galaxy::TestSupport::DiagnosticsReportBuilder.current_report("diagnostics_rspec_report").close_report
  end

  config.around(:each) do |example|
    @seed_value = Galaxy::TestSupport::Configuration.rspec_seed ||
        100000000000000000000000000000000000000 + rand(899999999999999999999999999999999999999)

    srand(@seed_value)

    example.run

    if (@example.exception)
      puts ("random seed for testing was: #{@seed_value}")
    end
  end

  config.after(:each) do
    if (@example.exception)
      Galaxy::TestSupport::DiagnosticsReportBuilder.current_report("diagnostics_rspec_report").within_section("Error:") do |report|
        minimal_fields   = Galaxy::TestSupport::Configuration.rspec_report_min_fields
        main_body_fields = Galaxy::TestSupport::Configuration.rspec_report_more_info_fields
        exclusions       = Galaxy::TestSupport::Configuration.rspec_report_exclude_fields
        expansions       = Galaxy::TestSupport::Configuration.rspec_report_expand_fields

        [minimal_fields, main_body_fields].each do |export_field_list|
          report.within_table(additional_information: minimal_fields != export_field_list) do |report_table|
            # report.within_table do |report_table|
            export_field_list.each do |export_field|
              case export_field[0]
                when :self
                  if export_field.length > 1
                    case export_field[1]
                      when :instance_variable_names
                        if export_field.length > 2
                          Galaxy::TestSupport::DiagnosticsReportBuilder.export_instance_variable(report_table,
                                                                                                 self,
                                                                                                 export_field[2],
                                                                                                 export_field[0..1],
                                                                                                 exclusions,
                                                                                                 expansions)
                        else
                          Galaxy::TestSupport::DiagnosticsReportBuilder.export_instance_variables(report_table,
                                                                                                  self,
                                                                                                  export_field,
                                                                                                  exclusions,
                                                                                                  expansions)
                        end

                      else
                        report_table.write_stats "#{export_field[1].to_s.humanize}:",
                                                 Galaxy::TestSupport::DiagnosticsReportBuilder.pretty_print_variable(
                                                     self.send(export_field[1]))
                    end
                  end

                when :example
                  if export_field.length > 1
                    case export_field[1]
                      when :instance_variable_names
                        if export_field.length > 2
                          Galaxy::TestSupport::DiagnosticsReportBuilder.export_instance_variable(report_table,
                                                                                                 @example,
                                                                                                 export_field[2],
                                                                                                 export_field[0..1],
                                                                                                 exclusions,
                                                                                                 expansions)
                        else
                          Galaxy::TestSupport::DiagnosticsReportBuilder.export_instance_variables(report_table,
                                                                                                  @example,
                                                                                                  export_field,
                                                                                                  exclusions,
                                                                                                  expansions)
                        end

                      when :callstack
                        report_table.write_stats "Call stack:", report.formatted_trace(@example.metadata[:caller])

                      when :exception
                        if @example.exception
                          if export_field.length > 2
                            case export_field[2]
                              when :backtrace
                                report_table.write_stats "Backtrace:", report.formatted_backtrace(@example.exception)
                              else
                                report_table.write_stats export_field[2], Galaxy::TestSupport::DiagnosticsReportBuilder.
                                    pretty_print_variable(@example.exception.send(export_field[2]))
                            end
                          else
                            report_table.write_stats "Exception:", @example.exception.to_s
                          end
                        end

                      else
                        report_table.write_stats "#{export_field[1].to_s.humanize}:",
                                                 Galaxy::TestSupport::DiagnosticsReportBuilder.pretty_print_variable(
                                                     @example.send(export_field[1]))
                    end
                  end

                when :logs
                  if Galaxy::TestSupport::Configuration.grab_logs
                    Galaxy::TestSupport::LogCapture.capture_logs report_table
                  end

                when :capybara_diagnostics
                  Galaxy::TestSupport::CapybaraDiagnostics.output_page_detail_section(@example.full_description,
                                                                                      report,
                                                                                      report_table)
              end
            end
          end
        end
      end
    end
  end
end