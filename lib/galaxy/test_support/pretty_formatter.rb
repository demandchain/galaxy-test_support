module Galaxy
  module TestSupport
    class PrettyFormatter
      class << self
        def format_string(unknown_string)
          PrettyFormatter.new(unknown_string).pretty_print
        end
      end

      def initialize(unknown_string)
        @unknown_string  = unknown_string
        @print_html_safe = @unknown_string.html_safe?
      end

      def pretty_print
        if @print_html_safe
          do_pretty_print = @unknown_string =~ /\#\&lt;[^ \t\n]+/
          do_pretty_print = do_pretty_print != (@unknown_string =~ /\#\&lt;[^ \t\n]+[ \t]*\n/)
        else
          do_pretty_print = @unknown_string =~ /\#\<[^ \t\n]+/
          do_pretty_print = do_pretty_print != (@unknown_string =~ /\#\<[^ \t\n]+[ \t]*\n/)
        end

        if do_pretty_print
          @indent_level       = 0
          @current_state      = :unknown
          @state_stack        = [:unknown]
          @current_pos        = 0
          @start_pos          = 0
          @unknown_string_len = @unknown_string.length
          @formatted_string   = ""

          while @current_pos < @unknown_string_len
            case @current_state
              when :unknown
                if @print_html_safe
                  do_pretty_print = @unknown_string[@current_pos..-1] =~ /\#\&lt;[^ \t\n]+/
                  do_pretty_print = do_pretty_print != (@unknown_string[@current_pos..-1] =~ /\#\&lt;[^ \t\n]+[ \t]*\n/)
                else
                  do_pretty_print = @unknown_string[@current_pos..-1] =~ /\#\<[^ \t\n]+/
                  do_pretty_print = do_pretty_print != (@unknown_string[@current_pos..-1] =~ /\#\<[^ \t\n]+[ \t]*\n/)
                end

                if do_pretty_print
                  if @print_html_safe
                    @current_pos += @unknown_string[@current_pos..-1] =~ /\#\&lt;[^ \t\n]+/
                  else
                    @current_pos += @unknown_string[@current_pos..-1] =~ /\#\<[^ \t\n]+/
                  end

                  if @current_pos
                    if @start_pos < @current_pos || @start_pos > 0
                      output_line(@unknown_string[@start_pos..@current_pos - 1])
                    else
                      @indent_level -= 1
                      @state_stack << :bottom_level
                    end

                    start_class
                  else
                    output_end
                  end
                else
                  output_end
                end

              when :value_end
                case @state_stack[-1]
                  when :unknown
                    @current_state = :unknown

                  when :class_name
                    group_value_end :variable,
                                    ">",
                                    end_append_text:     @indent_level == 0 ? "\n" : "",
                                    append_text:         " ",
                                    group_end_same_line: true,
                                    add_value:           true
                    @indent_level += 1

                  when :variable
                    group_value_end :variable_equal,
                                    ">",
                                    append_text:         " ",
                                    group_end_same_line: !@variable_set,
                                    end_append_text:     @indent_level == 0 ? "\n" : ""

                  when :variable_equal,
                      :variable_comma
                    group_value_end :variable_equal, ">",
                                    invalid_state:   true,
                                    end_append_text: @indent_level == 0 ? "\n" : ""

                  when :variable_value
                    group_value_end :variable_comma, ">",
                                    same_line:       true,
                                    end_append_text: @indent_level == 0 ? "\n" : ""

                  when :hash_key_symbol_post
                    group_value_end :hash_value, "}", append_text: " ", add_value: true

                  when :hash_key, :hash_key_symbol, :hash_key_string
                    group_value_end :hash_rocket, "}", append_text: " "

                  when :hash_rocket,
                      :hash_comma
                    group_value_end :hash_value,
                                    "}",
                                    invalid_state:  true,
                                    add_value:      true,
                                    group_indented: "true"

                  when :hash_value
                    group_value_end :hash_comma, "}", same_line: true

                  when :array
                    group_value_end :array_comma, "]"
                end

                @current_pos -= 1

              when :hash_rocket
                if @unknown_string[@current_pos] == ","
                  group_separator ",", :hash_value, "}", append_text: " "
                else
                  group_separator "=>", :hash_value, "}", append_text: " "
                end

              when :variable_equal
                @variable_set = true
                if @unknown_string[@current_pos] == ","
                  group_separator ",",
                                  :variable_value, ">",
                                  end_append_text: @indent_level == 0 ? "\n" : ""
                else
                  group_separator "=",
                                  :variable_value, ">",
                                  end_append_text: @indent_level == 0 ? "\n" : "",
                                  append_text:     " "
                end

              when :variable_comma
                group_separator ",",
                                :variable, ">",
                                end_append_text: @indent_level == 0 ? "\n" : ""

              when :array_comma
                group_separator ",", :array, "]"

              when :hash_comma
                group_separator ",", :hash_key, "}"

              when :whitespace
                case @unknown_string[@current_pos]
                  when " ", "\r", "\n"
                    @start_pos = @current_pos + 1

                  else
                    @start_pos     = @current_pos # probably redundant, but better safe than sorry...
                    @current_pos   -= 1
                    @current_state = @state_stack.pop
                end

              when :string
                if position_matches_string(@current_pos, "\\")
                  @current_pos += 1
                elsif position_matches_string(@current_pos, "\"")
                  @current_pos += translate_value("\"").length
                  value_end
                end

              when :value
                case @unknown_string[@current_pos]
                  when "{"
                    if @start_pos == @current_pos
                      start_grouping :hash_key
                    else
                      output_end
                    end

                  when "["
                    if @start_pos == @current_pos
                      start_grouping :array
                    else
                      output_end
                    end

                  when "\""
                    if position_matches_string(@current_pos, "\"")
                      start_quote
                    end

                  when "#"
                    if @start_pos == @current_pos &&
                        @current_pos < @unknown_string_len - 2 &&
                        position_matches_string(@current_pos + 1, "<")
                      start_class
                    end

                  when "="
                    case @state_stack[-1]
                      when :variable,
                          :hash_key,
                          :hash_key_string,
                          :hash_key_symbol,
                          :hash_key_symbol_post
                        value_end
                    end

                  when ":"
                    case @state_stack[-1]
                      when :hash_key
                        if @current_pos == @start_pos
                          @state_stack.pop
                          @state_stack << :hash_key_symbol
                        else
                          @state_stack.pop
                          @state_stack << :hash_key_symbol_post

                          @current_pos += 1
                          value_end
                        end
                    end

                  when "&", ">"
                    if position_matches_string(@current_pos, ">")
                      case @state_stack[-1]
                        when :class_name,
                            :variable,
                            :variable_equal,
                            :variable_value,
                            :variable_comma
                          value_end
                      end
                    elsif position_matches_string(@current_pos, "\"")
                      start_quote
                    end

                  when "}"
                    case @state_stack[-1]
                      when :hash_key,
                          :hash_key_symbol_post,
                          :hash_key_symbol,
                          :hash_key_string,
                          :hash_rocket,
                          :hash_value,
                          :hash_comma
                        value_end
                    end

                  when "]"
                    case @state_stack[-1]
                      when :array,
                          :array_comma
                        value_end
                    end

                  when ","
                    case @state_stack[-1]
                      when :hash_value,
                          :array,
                          :variable_value,
                          #unexpected, probably error states...
                          :variable,
                          :variable_equal,
                          :hash_key,
                          :hash_key_string,
                          :hash_key_symbol,
                          :hash_key_symbol_post,
                          :hash_rocket,
                          :hash_comma,
                          :variable_comma,
                          :array_comma
                        value_end
                    end

                  when " ", "\r", "\n"
                    case @state_stack[-1]
                      when :variable_value,
                          :array,
                          :hash_value
                        @current_pos += 1
                        @current_pos -= 1

                      else
                        value_end
                    end
                end
            end

            @current_pos += 1
          end

          if @current_pos < @unknown_string_len
            output_end
          end

          @formatted_string.rstrip!
          @formatted_string.html_safe if @print_html_safe
          @formatted_string
        else
          @unknown_string
        end
      end

      def start_quote
        if @start_pos == @current_pos
          if @state_stack[-1] == :hash_key && @start_pos == @current_pos
            @state_stack.pop
            @state_stack << :hash_key_string
          end

          @current_state = :string
          @current_pos   += translate_value("\"").length - 1
        else
          # This is almost certainly an error.  End it now...
          output_end
        end
      end

      def group_value_end(next_state, group_end_char, options = {})
        @state_stack.pop

        if position_matches_string @current_pos, group_end_char
          output_line(@unknown_string[@start_pos..@current_pos - 1], options)
          @start_pos = @current_pos

          safe_end = translate_value(group_end_char)
          end_grouping safe_end, options
          @current_pos += 1

        else
          if options[:invalid_state]
            output_end
          else
            output_line(@unknown_string[@start_pos..@current_pos - 1], options)

            if options[:append_text]
              @formatted_string << options[:append_text]
            end

            @state_stack << next_state
            @state_stack << :value if options[:add_value]
            @start_pos     = @current_pos
            @current_state = :whitespace
          end
        end
      end

      def value_end
        @current_state = :value_end
        @current_pos   -= 1
      end

      def group_separator(separator_value, next_state, group_end_char, options = {})
        if position_matches_string(@current_pos, separator_value)
          safe_separator = translate_value(separator_value)

          @formatted_string << @unknown_string[@start_pos..(@current_pos + safe_separator.length - 1)]

          if options[:append_text]
            @formatted_string << options[:append_text]
          end

          @start_pos   = @current_pos + safe_separator.length
          @current_pos += safe_separator.length - 1
          @state_stack << next_state
          @state_stack << :value
          @current_state = :whitespace

        elsif position_matches_string(@current_pos, group_end_char)
          end_grouping translate_value(group_end_char), options

        else
          # Some kind of error, exit out
          output_end
        end
      end

      def end_grouping(safe_end, options = {})
        @indent_level -= 1

        if options[:group_end_same_line]
          @formatted_string.strip!
          @formatted_string << @unknown_string[@start_pos..@current_pos + safe_end.length - 1]
        else
          output_line(@unknown_string[@start_pos..@current_pos + safe_end.length - 1])

          if options[:end_append_text]
            @formatted_string << options[:end_append_text]
          end
        end

        @indent_level -= 1
        if @state_stack[-1] == :bottom_level
          @state_stack.pop
          @indent_level += 1
        end

        @current_pos   += safe_end.length - 1
        @start_pos     = @current_pos + 1
        @current_state = :value_end
      end

      def start_grouping group_type
        if @state_stack[-1] == :array
          @state_stack << :bottom_level
        else
          @indent_level += 1
        end

        output_line(@unknown_string[@start_pos..@current_pos])
        @indent_level += 1
        @start_pos    = @current_pos + 1
        @state_stack << group_type
        @state_stack << :value
        @current_state = :whitespace
      end

      def start_class
        if @state_stack[-1] == :array
          @state_stack << :bottom_level
          @indent_level -= 1
        end
        @indent_level += 1

        @start_pos = @current_pos

        @variable_set = false
        @state_stack << :class_name

        @current_pos   += 1
        @current_state = :value

        @formatted_string.rstrip!
      end

      def output_end
        unless @start_pos >= @unknown_string_len
          @formatted_string << "\n" unless @formatted_string[-1] == "\n"
          @formatted_string << @unknown_string[@start_pos..-1]
        end

        @current_pos = @unknown_string_len
      end

      def translate_value(value)
        safe_string = value

        if @print_html_safe
          safe_string = "".html_safe
          safe_string << value
        end

        safe_string
      end

      def position_matches_string(test_position, test_string)
        safe_string = translate_value(test_string)

        test_position <= @unknown_string_len - safe_string.length &&
            @unknown_string[test_position..(test_position + safe_string.length - 1)] == safe_string
      end

      def output_line(text, options = {})
        unless text.blank?
          unless options[:same_line]
            if (@formatted_string[-1] == " ")
              @formatted_string.rstrip!
            end

            @formatted_string << "\n" unless @formatted_string.length == 0 || @formatted_string[-1] == "\n"
            @formatted_string << " " * (2 * @indent_level)
          end

          @formatted_string << text
        end
      end
    end
  end
end