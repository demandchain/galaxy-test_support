require ::File.expand_path('configured_report', File.dirname(__FILE__))

module Galaxy
  module TestSupport
    class Configuration
      @@rspec_seed        = nil
      @@user_log_files    = {}
      @@default_num_lines = 500
      @@grab_logs         = true

      @@configured_reports = {
          rspec:    Galaxy::TestSupport::ConfiguredReport.new(
                        min_fields:           [
                                                  :self__instance_variables__example__full_description,
                                                  :self__instance_variables__example__location,
                                                  :self__instance_variables__example__exception__to_s,
                                                  :self__instance_variables__example__exception__backtrace
                                              ],
                        more_info_fields:     [
                                                  :self__instance_variables,
                                                  :self__instance_variables__example__instance_variables,
                                                  :self__instance_variables__example__metadata__caller,
                                                  :logs,
                                                  :capybara_diagnostics
                                              ],
                        expand_fields:        [
                                                  :self__instance_variables,
                                                  :self__instance_variables__example__instance_variables,
                                                  :self__instance_variables__response,
                                                  :self__instance_variables__controller,
                                                  :self__instance_variables__request,
                                              ],
                        expand_inline_fields: [
                                                  :self__instance_variables____memoized
                                              ],
                        exclude_fields:       [
                                                  :self__instance_variables__fixture_connections,
                                                  :self__instance_variables__example,
                                                  :self__instance_variables__example__instance_variables__example_group_instance,
                                                  :self__instance_variables__example__instance_variables__metadata
                                              ]
                    ),
          cucumber: Galaxy::TestSupport::ConfiguredReport.new(
                        min_fields:           [
                                                  :scenario__feature__instance_variables__title,
                                                  :scenario__feature__instance_variables__location,
                                                  :scenario__instance_variables__title,
                                                  :scenario__instance_variables__location,
                                                  :scenario__exception__to_s,
                                                  :scenario__exception__backtrace
                                              ],
                        more_info_fields:     [
                                                  :scenario__instance_variables,
                                                  :scenario__feature__instance_variables__comment,
                                                  :scenario__feature__instance_variables__keyword,
                                                  :scenario__feature__instance_variables__description,
                                                  :scenario__feature__instance_variables__gherkin_statement,
                                                  :scenario__feature__instance_variables__tags,
                                                  :scenario__instance_variables__current_visitor__configuration,
                                                  :self__instance_variables,
                                                  :logs,
                                                  :capybara_diagnostics
                                              ],
                        expand_fields:        [
                                                  :scenario__instance_variables,
                                                  :self__instance_variables,
                                              ],
                        expand_inline_fields: [
                                              ],
                        exclude_fields:       [
                                                  :scenario__instance_variables__background,
                                                  :scenario__instance_variables__feature,
                                                  :scenario__instance_variables__current_visitor,
                                                  :scenario__instance_variables__raw_steps,
                                                  :scenario__instance_variables__title,
                                                  :scenario__instance_variables__location,
                                                  :self__instance_variables____cucumber_runtime,
                                                  :self__instance_variables____natural_language,
                                                  :self__instance_variables___rack_test_sessions,
                                                  :self__instance_variables___rack_mock_sessions,
                                                  :self__instance_variables__integration_session
                                              ]
                    ),
          spinach:  Galaxy::TestSupport::ConfiguredReport.new(
                        min_fields:           [
                                                  :failure_description,
                                                  :running_scenario__instance_variables__feature__name,
                                                  :running_scenario__instance_variables__name,
                                                  :running_scenario__instance_variables__line,
                                                  :step_data__name,
                                                  :step_data__line,
                                                  :exception__to_s,
                                                  :exception__backtrace
                                              ],
                        more_info_fields:     [
                                                  :running_scenario__instance_variables__feature__tags,
                                                  :running_scenario__instance_variables,
                                                  :step_data__instance_variables,
                                                  :step_definitions__instance_variables,
                                                  :logs,
                                                  :capybara_diagnostics
                                              ],
                        expand_fields:        [
                                                  :running_scenario__instance_variables,
                                                  :step_data__instance_variables,
                                                  :step_definitions__instance_variables
                                              ],
                        expand_inline_fields: [
                                              ],
                        exclude_fields:       [
                                                  :running_scenario__instance_variables__feature,
                                                  :step_data__scenario__instance_variables__feature,
                                                  :running_scenario__instance_variables__name,
                                                  :running_scenario__instance_variables__line,
                                                  :step_data__name,
                                                  :step_data__line
                                              ]
                    )
      }

      class << self
        # rspec_seed is the seed value used to seed the srand function at the start of a test
        # suite.  This is done to allow tests with random elements in them to be repeatable.
        # If a test fails, simply set Galaxy::TestSupport::Configuration.rspec_seed to the
        # value of the failed tests seed value (output in the stdout and the generated report)
        # and run the test again.  This should re-run the exact same test, resulting in a
        # repeatable test even with randomization in it.
        def rspec_seed=(value)
          @@rspec_seed = value
          srand(value)
        end

        def rspec_seed
          @@rspec_seed
        end

        # grab_logs indicates if the system should try to automatically grab a tail of
        # the log file if outputing a diagnostics report.
        #
        # The system will try to grab the following log files:
        #   * Rails.env.log
        #   * any user specified logs
        #
        # The log capture is done by reading from the end of the file
        # of the log file.  If the log file cannot be found, or if the system
        # cannot open the file (no access rights, etc.) nothing will be output.
        #
        # Related options:
        #   user_log_files
        #   num_lines
        #   add_log_file
        #   remove_log_file
        def grab_logs=(value)
          @@grab_logs = true
        end

        def grab_logs
          @@grab_logs
        end

        # user_log_files returns a hash of all of the log files which
        # the user has specified are to be grabbed.
        #
        # The keys are the relative paths of the log files to be
        # grabbed, and the values are the options specified for the
        # files.  The values may be an empty hash.
        def user_log_files
          @@user_log_files.clone
        end

        # num_lines returns the number of lines that will be grabbed
        # for a file.  If no file name is supplied, or the name does not match a
        # user file, the default log length will returned.
        def num_lines(log_file_name=nil)
          @@user_log_files[log_file_name].try(:[], :num_lines) || @@default_num_lines
        end

        # default_num_lines sets the default number of lines to extract from the log file
        def default_num_lines=(value)
          @@default_num_lines = value
        end

        # Adds the specified log file to the list of log files to capture.
        # If the log file is already in the list, the passed in options will be merged with
        # the existing options.
        def add_log_file(log_file_name, options = {})
          @@user_log_files[log_file_name] ||= {}
          @@user_log_files[log_file_name] = @@user_log_files[log_file_name].merge options
        end

        # Removes the specified log file from the list of log files to capture.
        # NOTE:  You cannot remove the default log file.
        def remove_log_file(log_file_name)
          @@user_log_files.delete log_file_name
        end

        # returns the report configuration object for that type of report
        #
        # values for report_name:
        #   :rspec
        #   :cucumber
        #   :spinach
        #   :capybara
        def report_configuration(report_name)
          @@configured_reports[report_name]
        end
      end
    end
  end
end