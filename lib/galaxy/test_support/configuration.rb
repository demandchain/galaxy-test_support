module Galaxy
  module TestSupport
    class Configuration
      @@rspec_seed        = nil
      @@user_log_files    = {}
      @@default_num_lines = 500
      @@grab_logs         = true

      @@rspec_min_fields       = [
          :example__full_description,
          :example__location,
          :example__exception,
          :example__exception__backtrace
      ]
      @@rspec_more_info_fields = [
          :self__instance_variable_names,
          :example__instance_variable_names,
          :example__callstack,
          :logs,
          :capybara_diagnostics
      ]
      @@rspec_exclude_fields   = [
          :self__instance_variable_names__fixture_connections,
          :self__instance_variable_names__example,
          :example__instance_variable_names__example_group_instance,
          :example__instance_variable_names__metadata
      ]
      @@rspec_expand_fields    = [
          :self__instance_variable_names__response,
          :self__instance_variable_names__controller,
          :self__instance_variable_names__request,
          :self__instance_variable_names____memoized
      ]

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

        # I'm making the reports more configurable.
        #
        # Starting with rspec, you can specify what is exported
        # in what order.
        #
        # There are 2 blocks of fields which can be exported:
        #   * min_fields
        #   * more_info_fields
        #
        # Anything which can be exported can be exported in either or both blocks.
        #
        # Simply specify an array of what fields to export, and those items will
        # be exported as specified.
        #
        # To see a list of the options you have, there are 2 special calls you can
        # make:
        #   * rspec_report_list_all_fields
        #   * rspec_report_list_all_exclude_fields
        #
        # There are some special fields which end with a ?.
        # These fields allow you to specify sub-items which can be excluded or included
        # explicitly.
        #
        # If excluded, when the parent object is exported wihtout an explicit included
        # sub-item, all sub-items are exported, except for the excluded items.
        #
        # If an item has sub-items, and it supports the explicity inclusion of a sub-item,
        # just the sub-item can be exported if specified.
        #
        # When exporting instance variabes, some instance variables can be exported as if they
        # were a top-level item.  That is, instead of a pretty_inspect, the instance variables
        # for those items are iterated, and excluded or exported just like normal instance varaibles.
        #
        # I know that this is poorly documented, and that there are a lot of things I could do to make
        # it more generic, but this is a first pass, and I don't expect it to be used much except by me
        # to setup the default export.
        #
        # As inspiration strikes, and needs arise, I will make updates.
        #
        # Otherwise, it may just stay as it is...
        def rspec_report_min_fields()
          Galaxy::TestSupport::Configuration.split_field_symbols(@@rspec_min_fields)
        end

        def rspec_report_min_fields=(value)
          @@rspec_min_fields = value.clone
        end

        def rspec_report_more_info_fields()
          Galaxy::TestSupport::Configuration.split_field_symbols(@@rspec_more_info_fields)
        end

        def rspec_report_more_info_fields=(value)
          @@rspec_more_info_fields = value.clone
        end

        def rspec_report_exclude_fields()
          Galaxy::TestSupport::Configuration.split_field_symbols(@@rspec_exclude_fields)
        end

        def rspec_report_exclude_fields=(value)
          @@rspec_exclude_fields = value.clone
        end

        def rspec_report_expand_fields()
          Galaxy::TestSupport::Configuration.split_field_symbols(@@rspec_expand_fields)
        end

        def rspec_report_expand_fields=(value)
          @@rspec_expand_fields = value.clone
        end

        def rspec_report_list_all_exclude_fields()
          exclude_examples = [
              :self__instance_variable_names__?,
              :example__instance_variable_names__?,
              :self__instance_variable_names____memoized__?,
              :example__instance_variable_names____memoized__?
          ]

          @@rspec_expand_fields.each do |expand_field|
            exclude_examples << "#{expand_field}__?".to_sym
          end

          exclude_examples
        end

        def rspec_report_list_all_expand_fields()
          expand_examples = [
              :self__instance_variable_names__?,
              :example__instance_variable_names__?,
          ]

          expand_examples
        end

        def rspec_report_list_all_fields()
          field_options = [
              :self__?,
              :example__?,
              :self__instance_variable_names,
              :example__instance_variable_names,
              :self__instance_variable_names__?,
              :example__instance_variable_names__?,
              :self__callstack,
              :example__exception,
              :example__exception__backtrace,
              :example__exception__?,
              :logs,
              :capybara_diagnostics
          ]

          field_options
        end

        def split_field_symbols(full_symbol_array)
          full_symbol_array.map do |full_symbol|
            Galaxy::TestSupport::Configuration.split_full_field_symbol(full_symbol)
          end
        end

        def split_full_field_symbol(full_symbol)
          field_symbols = full_symbol.to_s.split("__")

          field_symbols.reduce([]) do |array, symbol|
            if (array.length > 0 && array[-1].blank?)
              array.pop
              array << "__#{symbol}".to_sym
            else
              if (symbol.blank?)
                array << nil
              else
                array << symbol.to_sym
              end
            end
          end
        end
      end
    end
  end
end