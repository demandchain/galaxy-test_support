module TestSupport
  class ConfiguredReport
    # ConfiguredReport outputs an error report based on symbol based configurations
    #
    # The configurations are as follows:
    #   min_fields
    #   more_info_fields
    #   expand_fields
    #   expand_inline_fields
    #   exclude_fields
    #
    # min_field
    #   This is a list of the fields which are to be output at the top of the report
    #   such that they are always visible.
    #   Items in the min list which cannot be found will output an error.
    #
    # more_info_fields
    #   This is a list of the fields which are to be output below the min fields
    #   in a section that is initially hidden.  The user can expand these values
    #   If/when they need to.
    #   Items in the more info list which cannot be found will output an error.
    #
    # expand_fields
    #   This is a list of the fields which are to be expanded when they are encountered.
    #   Expanded fields are shown in a sub-table of values so that the instance variables
    #   are then each output.
    #   items which are to be expanded may be explicitly or implicitly exported.
    #   items which are not encountered but are in the expand list will be ignored.
    #
    # expand_inline_fields
    #   This is a list of the fields which are to be expanded, but unlike expanded fields
    #   when these items are expanded, they will be placed at the same level as the current
    #   items rather than in a sub-table.
    #
    # exclude_fields
    #   This is a list of the fields which are not to be output when they are encountered.
    #   There are many implicit ways to output a field (such as the expanded fields).
    #   If a field is to be implicityly exported, it will not be exported if it is in this
    #   list.  A field can always be explicitly exported.  Items not encountered but
    #   in the exclude list will be ignored.
    #
    # field names follow a set pattern:
    #   <object_name>__<function_property_or_hash_name>
    #
    # You can have as many following __<function_or_property_name> values as you need.
    #
    # Examples:
    #   self.exception.backtrace would be specified as: :self__exception__backtrace
    #   self.my_hash[:my_key] would be specified as: :self__my_hash__my_key
    #   self.to_s would be specified as: :self__to_s
    #
    # There are a handful of special conditions:
    #   if the last_line is to_s, the label that is output will not be to_s, but the previous item level
    #
    # :logs
    #   This will output the logs using TestSupport::LogCapture.capture_logs
    #   Unlike normal items, if there are no logs to export, this will not generate an error.
    #
    # :capybara_diagnostics
    #   This will output Capybara infomration using
    #   TestSupport::CapybaraDiagnostics.output_page_detail_section.
    #   NOTE:  This option requres a parameter be passed into the options for :diagnostics_name
    #   Unlike normal items, if Capybara is not being used, this will not generate an error.
    #
    # instance_variables
    #   This allows you to access the instance variables for an object.
    #   self.instance_variable_get("@my_variable_name") would be specified as: self__instance_variables__my_variable_name
    #   self.instance_variables can be used to output all instance variables.
    #   if self.instance_variables is placed in the expand option, the instance variables and their values will
    #   be placed in a sub-table.
    #   Unlike normal items, if there are no instance variables, this will not generate an error.
    def initialize(options = {})
      @min_fields           = []
      @more_info_fields     = []
      @expand_fields        = []
      @expand_inline_fields = []
      @exclude_fields       = []
      @report_objects       = {}

      self.min_fields           = options[:min_fields]
      self.more_info_fields     = options[:more_info_fields]
      self.expand_fields        = options[:expand_fields]
      self.expand_inline_fields = options[:expand_inline_fields]
      self.exclude_fields       = options[:exclude_fields]
    end

    def min_fields=(value)
      @min_fields = split_field_symbols(value)
    end

    def more_info_fields=(value)
      @more_info_fields = split_field_symbols(value)
    end

    def expand_fields=(value)
      @expand_fields = split_field_symbols(value)
    end

    def expand_inline_fields=(value)
      @expand_inline_fields = split_field_symbols(value)
    end

    def exclude_fields=(value)
      @exclude_fields = split_field_symbols(value)
    end

    def add_report_objects(report_object_hash)
      @report_objects.merge! report_object_hash
    end

    def generate_report_for_object(report, options = {})
      [@min_fields, @more_info_fields].each do |export_field_list|
        report.within_table(additional_information: @min_fields != export_field_list) do |report_table|
          export_field_list.each do |export_field|
            export_field_record(export_field,
                                @report_objects[export_field[0]],
                                export_field[0],
                                report,
                                report_table,
                                0,
                                options.merge(report_object_set: true))
          end
        end
      end
    end

    def expand_field_object(export_field, expand_object, symbol_name, report, report_table, level, options = {})
      expand_inline = options.delete(:expand_inline)
      if (expand_inline)
        sub_vars_report = report_table
      else
        sub_vars_report = TestSupport::DiagnosticsReportBuilder::ReportTable.new
      end

      if expand_object.is_a?(Hash)
        expand_object.each do |sub_symbol_name, value|
          sub_export_field = export_field.clone
          sub_export_field << sub_symbol_name.to_sym

          export_field_record(sub_export_field,
                              value,
                              sub_symbol_name.to_sym,
                              report,
                              sub_vars_report,
                              level + 1,
                              options.merge(report_object_set: true))
        end
      else
        sub_export_field = export_field.clone
        sub_export_field << :instance_variables

        export_field_record(sub_export_field,
                            expand_object,
                            symbol_name,
                            report,
                            sub_vars_report,
                            level + 1,
                            options.merge(report_object_set: true))
      end

      unless (expand_inline)
        report_table.write_stats symbol_name,
                                 sub_vars_report.full_table,
                                 prevent_shrink:      true,
                                 exclude_code_block:  true,
                                 do_not_pretty_print: true
      end
    end

    def export_field_record(export_field, parent_object, parent_object_name, report, report_table, level, options = {})
      report_object = nil
      if (options.delete(:report_object_set))
        report_object = parent_object
      else
        if parent_object_name == :instance_variables
          report_object = get_instance_variable parent_object, "@#{export_field[level]}"
        else
          if export_field[level] == :instance_variables
            report_object = parent_object
          else
            if parent_object.respond_to?(export_field[level])
              report_object = parent_object.send(export_field[level])
            elsif parent_object.respond_to?(:[])
              report_object = parent_object.send(:[], export_field[level])
            else
              report_object = nil
              print_value   = "Could not identify field: #{export_field[0..level].join("__")} while exporting #{export_field.join("__")}"

              report_table.write_stats "ERROR", print_value
            end
          end
        end
      end

      if (level == 0 || report_object) &&
          (level > 0 || export_field[level] == parent_object_name)
        if level < export_field.length - 1
          export_field_record(export_field,
                              report_object,
                              export_field[level],
                              report,
                              report_table,
                              level + 1,
                              options)
        else
          case export_field[level]
            when :instance_variables
              if expand_variable?(export_field[0..-2], export_field[-1]) &&
                  !expand_variable_inline?(export_field[0..-2], export_field[-1])
                instance_table = TestSupport::DiagnosticsReportBuilder::ReportTable.new
              else
                instance_table = report_table
              end

              report_object.instance_variable_names.each do |variable_name|
                symbol_name = variable_name[1..-1].to_sym

                unless exclude_variable?(export_field, symbol_name)
                  instance_object = get_instance_variable report_object, variable_name

                  if expand_variable?(export_field, symbol_name)
                    sub_export_field = export_field.clone
                    sub_export_field << symbol_name.to_sym

                    expand_field_object(sub_export_field,
                                        instance_object,
                                        symbol_name,
                                        report,
                                        instance_table,
                                        level + 1,
                                        options.merge(expand_inline: expand_variable_inline?(export_field, symbol_name)))
                  else
                    instance_table.write_stats symbol_name, instance_object
                  end
                end
              end

              if expand_variable?(export_field[0..-2], export_field[-1]) &&
                  !expand_variable_inline?(export_field[0..-2], export_field[-1])
                report_table.write_stats export_field[-2],
                                         instance_table.full_table,
                                         prevent_shrink:      true,
                                         exclude_code_block:  true,
                                         do_not_pretty_print: true
              end

            when :logs
              if TestSupport::Configuration.grab_logs
                TestSupport::LogCapture.capture_logs report_table
              end

            when :capybara_diagnostics
              TestSupport::CapybaraDiagnostics.output_page_detail_section(options[:diagnostics_name] || "Capybara Diagnostics",
                                                                          report,
                                                                          report_table)

            else
              if expand_variable?(export_field[0..-2], export_field[-1])
                expand_field_object(export_field,
                                    report_object,
                                    export_field[-1],
                                    report,
                                    report_table,
                                    level,
                                    options.merge({ expand_inline:
                                                        expand_variable_inline?(export_field[0..-2], export_field[-1]) }))
              else
                if export_field[-1] == :to_s
                  print_name = export_field[-2]
                else
                  print_name = export_field[-1]
                end

                report_table.write_stats print_name, report_object
              end
          end
        end
      end
    end

    def exclude_variable?(export_field, variable_name)
      set_contains_variable?(@exclude_fields, export_field, variable_name)
    end

    def expand_variable?(export_field, variable_name)
      set_contains_variable?(@expand_fields, export_field, variable_name) ||
          set_contains_variable?(@expand_inline_fields, export_field, variable_name)
    end

    def expand_variable_inline?(export_field, variable_name)
      set_contains_variable?(@expand_inline_fields, export_field, variable_name)
    end

    def set_contains_variable?(variable_set, export_field, variable_name)
      variable_set.any? do |exclusion_item|
        found_item = true

        if exclusion_item.length == export_field.length + 1
          export_field.each_with_index do |export_name, export_index|
            found_item &&= (exclusion_item[export_index] == export_name)
          end

          found_item &&= (exclusion_item[export_field.length] == variable_name)

          found_item
        end
      end
    end

    def split_field_symbols(full_symbol_array)
      full_symbol_array.map do |full_symbol|
        split_full_field_symbol(full_symbol)
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

    def get_instance_variable(the_object, instance_variable)
      variable_name = instance_variable.to_s
      variable_name = variable_name[1..-1] if variable_name[0] == "@"
      if the_object.respond_to?(variable_name) && the_object.method(variable_name).arity == 0
        the_object.send(variable_name)
      else
        the_object.instance_variable_get(instance_variable)
      end
    end
  end
end