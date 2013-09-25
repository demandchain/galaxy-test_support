require ::File.expand_path('diagnostics_report_builder', File.dirname(__FILE__))

module Galaxy
  module TestSupport
    class CapybaraDiagnostics
      def self.output_page_details(screenshot_name)
        my_page = Capybara.current_session
        if (my_page)
          DiagnosticsReportBuilder.current_report.within_section("Page Dump:") do |report|
            report.within_table do |report_table|
              report_table.write_stats "Page URL:", my_page.current_url if my_page.try(:current_url)

              if my_page.respond_to?(:html)
                report_table.write_stats "Page HTML:", report.page_dump(my_page.html)
                report_table.write_stats "Page:", report.page_link(my_page.html)
              end

              browser = my_page.try(:driver)
              browser = browser.try(:browser) unless browser.respond_to?(:save_screenshot)

              if browser.respond_to?(:save_screenshot)
                Dir.mkdir("./tmp") unless File.directory?("./tmp")

                filename = screenshot_name
                filename = SecureRandom.uuid if filename.blank?
                filename = filename[Dir.pwd.length..-1] if filename.start_with?(Dir.pwd)
                filename = filename[1..-1] if filename.start_with?("/")
                filename = filename["features/".length..-1] if filename.start_with?("features/")
                filename = filename.gsub("/", "-").gsub(" ", "_").gsub(":", "-")

                filename = File.expand_path("./tmp/#{filename}.png")

                begin
                  browser.save_screenshot(filename)
                  report_table.write_stats "Screen Shot:", report.image_link(filename)
                rescue Capybara::NotSupportedByDriverError
                  report_table.write_stats "Screen Shot:", "Could not save screenshot."
                end
              end
            end
          end
        end
      end

      # This function calls a "finder" function with the passed in arguments on the passed in object.
      # If the function succeeds, it doesn't do anything else.
      # If the function fails, it tries to figure out why, and provide diagnostic
      # information for further analysis.
      #
      # Parameters:
      #   test_object - the object to call the finder function on.  Examples could be:
      #     self
      #     page
      #     test_finder(:find, ...)
      #   function_name - this is the "finder" function to be called.  Examples could be:
      #     all
      #     find
      #     fill_in
      #     click_link
      #     select
      #     etc.
      #   args - the arguments that you would pass into the function normally.
      #
      #  Usage:
      #   Instead of calling: <test_object>.<function> <args>
      #   you would call:     test_finder <test_object>, :<function>, <args>
      def self.test_finder(test_object, function_name, *args)
        FindAction.new(test_object, function_name, *args).run
      end

      # At the end of the day, almost everything in Capybara calls all to find the element that needs
      # to be worked on.  The main difference is if it is synchronized or not.
      #
      # The FindAction class also uses all, but it is never synchronized, and its primary purpose
      # is really to output a bunch of diagnostic information to try to help you do a postmortem on
      # just what is happening.
      #
      # A lot of things could be happening, so a lot of information is output, not all of which is
      # relevant or even useful in every situation.
      #
      # The first thing output is the error (the problem)
      # Then what action was being tried is output (context)
      #
      # In case the problem was with finding the desired element, a list of all elements which
      # could be found using the passed in parameters is output.
      #
      # In case the problem was with context (inside a within block on purpose or accidentally)
      # a list of all other elements which could be found on the page using the passed in
      # parameters is output.
      #
      # In case the problem is something else, we output a screenshot and the page HTML.
      #
      # In case the problem has now solved itself, we try the action again.  (This has a very low
      # probability of working as this basically devolves to just duplicating what Capybara is already doing,
      # but it seems like it is worth a shot at least...)
      #
      # In case the problem is a driver bug (specifically Selenium which has some known issues) and
      # is in fact why I even bother trying to do this, try performing the action via javascript.
      # NOTE:  As noted in many blogs this type of workaround is not generally a good idea as it can
      #        result in false-positives.  However since Selenium is buggy, this is the
      #        best solution I have other than going to capybara-webkit or poltergeist
      class FindAction
        def initialize(test_object, function_name, *args)
          @test_object   = test_object
          @function_name = function_name
          @args          = args
        end

        def run
          begin
            @test_object.send(@function_name, *@args)
          rescue
            DiagnosticsReportBuilder.current_report.within_section("An error occurred while processing \"#{@function_name.to_s}\":") do |report|
              report.within_table do |report_table|
                report_table.write_stats "Error:", $!.to_s
                report_table.write_stats "Backtrace:", $!.backtrace.join("<br />")
                output_basic_details report_table
                output_finder_details report_table

                return @return_value if retry_action_with_found_element report_table
                if alternate_action_with_found_element report_table
                  Galaxy::TestSupport::CapybaraDiagnostics.output_page_details "#{DateTime.now.strftime("%Y_%m_%d")}_failure_#{SecureRandom.uuid}.png"
                  return @return_value
                end
              end
            end

            raise $!
          end
        end

        # Dump the arguments to the function to the console for analysis.
        def output_basic_details report_table
          report_table.write_stats "Function:", @function_name.to_s

          args_table = Galaxy::TestSupport::DiagnosticsReportBuilder::ReportTable.new
          search_args.each_with_index do |the_arg, arg_index|
            args_table.write_stats "[#{arg_index}]", dump_value(the_arg) + ((arg_index == 0 && @args[0] != the_arg) ? " (guessed)" : "")
          end
          if options
            options.each do |key, value|
              args_table.write_stats key, dump_value(value)
            end
          end

          report_table.write_stats "Args:", args_table.full_table


          if Capybara.current_session.driver.respond_to? :evaluate_script
            report_table.write_stats "Window Height:", Capybara.current_session.driver.evaluate_script("window.innerHeight")
            report_table.write_stats "Window Width:", Capybara.current_session.driver.evaluate_script("window.innerWidth")
          end
        end

        # Output some hopefully diagnostically useful information about the item being
        # searched for.
        #
        # Start by trying to use all to find all instances, even if hidden.
        # This may help identify why the right one isn't being found.
        def output_finder_details report_table
          if guessed_types.length > 1
            report_table.write_stats "Alternate possible types:", guessed_types.join("<br />")
          end

          all_page_elements = Capybara.current_session.all(*search_args, visible: false).to_a
          all_elements report_table
          report_table.write_stats "Total elements found:", all_elements.length
          all_elements.each_with_index do |element, element_index|
            report_table.write "Element[#{element_index}]", analyze_report_element(element)
          end

          if (all_elements.length != all_page_elements.length)
            all_other_elements = all_page_elements - all_elements
            report_table.write_stats "Total elements found elsewhere:", all_other_elements.length
            all_other_elements.each_with_index do |element, element_index|
              report_table.write "Other Element[#{element_index}]", analyze_report_element(element)
            end
          end
        end

        def retry_action_with_found_element report_table
          return_result = false

          if found_element
            result = "Success"

            begin
              case @function_name.to_s
                when "click_link_or_button", "click_link", "click_button"
                  @return_value = found_element.click
                when "fill_in"
                  @return_value = found_element.set(options[:with])
                when "choose", "check"
                  @return_value = found_element.set(true)
                when "uncheck"
                  @return_value = found_element.set(false)
                when "select"
                  @return_value = found_element.select_option
                when "unselect"
                  @return_value = found_element.unselect_option
                when "find", "find_field", "find_link", "find_button", "find_by_id"
                  @return_value = found_element
                when "all"
                  @return_value = all_elements
                when "first"
                  @return_value = all_elements.first
                else
                  result = "Could not decide what to do with #{@function_name}"
                  raise new Exception("unknown action")
              end

              return_result = true
            rescue
              result ||= "Still couldn't do the action - #{$!.to_s}."
            end

            report_table.write_stats "Retrying action:", result
          end

          return_result
        end

        def alternate_action_with_found_element report_table
          return_result = false

          result = "Could not attempt to try the action through an alternate method."
          if found_element &&
              Capybara.current_session.driver.respond_to?(:evaluate_script)
            begin
              native_id = get_attribute found_element, "id"
              if (native_id)
                case @function_name.to_s
                  when "click_link_or_button", "click_link", "click_button"
                    @return_value = Capybara.current_session.driver.evaluate_script("$(\"\##{native_id}\")[0].click()")
                  when "fill_in"
                    @return_value = Capybara.current_session.driver.evaluate_script("$(\"\##{native_id}\")[0].val(\"#{options[:with]}\")")
                  when "choose", "check"
                    @return_value = Capybara.current_session.driver.evaluate_script("$(\"\##{native_id}\")[0].val(\"checked\", true)")
                  when "uncheck"
                    @return_value = Capybara.current_session.driver.evaluate_script("$(\"\##{native_id}\")[0].val(\"checked\", false)")
                  when "select"
                    @return_value = Capybara.current_session.driver.evaluate_script("$(\"\##{native_id}\")[0].val(\"selected\", true)")
                  when "unselect"
                    @return_value = Capybara.current_session.driver.evaluate_script("$(\"\##{native_id}\")[0].val(\"selected\", false)")
                  else
                    result = "Could not decide what to do with #{@function_name}"
                    raise new Exception("unknown action")
                end

                return_result = true
              end
            rescue
              result ||= "Still couldn't do the action - #{$!.to_s}."
            end
          end

          report_table.write_stats "Trying alternate action:", result
          return_result
        end

        def found_element
          if all_elements && all_elements.length == 1
            all_elements[0]
          else
            nil
          end
        end

        def all_elements report_table = nil
          unless @all_elements
            if options && options.has_key?(:from)
              from_within = FindAction.new(@test_object, :find, [:select, options[:from]])
              sub_report  = Galaxy::TestSupport::DiagnosticsReportBuilder::ReportTable.new
              from_within.output_basic_details sub_report
              from_within.output_finder_details sub_report
              report_table.write_stats "Within block:", sub_report.full_table

              from_element = from_within.found_element

              unless from_element
                @all_elements = []
                return @all_elements
              end
            else
              from_element = @test_object
            end

            @all_elements = from_element.all(*search_args, visible: false).to_a
          end

          @all_elements
        end

        private
        def search_args
          init_search_args
          @search_args
        end

        def options
          init_search_args
          @options
        end

        def init_search_args
          unless @search_args
            @search_args = @args.clone
            if @search_args.last.is_a? Hash
              @options = test_args.pop
            end
            if guessed_types.length > 0 && @search_args[0] != guessed_types[0]
              @search_args.insert(0, guessed_types[0])
            end
          end
        end

        # Just a utility/support function to dump a value to the console
        # in a "pretty" manner
        def dump_value(value)
          if value.is_a?(Symbol)
            ":#{value.to_s}"
          elsif value.is_a?(String)
            "\"#{value.to_s}\""
          else
            value.to_s
          end
        end

        # a list of guesses as to what kind of object is being searched for
        def guessed_types
          unless @guessed_types
            if search_args.length > 0
              if search_args[0].is_a?(Symbol)
                @guessed_types = [search_args[0]]
              else
                @guessed_types = [:id, :css, :xpath, :link_or_button, :fillable_field, :radio_button, :checkbox, :select, :option,
                                  :file_field, :table, :field, :fieldset, :content].select do |test_type|
                  begin
                    @test_object.all(test_type, *search_args, visible: false).length > 0
                  rescue
                    # Normally bad form, but for this function, we just don't want this to throw errors.
                    # We are only concerned with whatever actually succeeds.
                    false
                  end
                end
              end
            end
          end

          @guessed_types
        end

        # Output any information we can easily obtain about a DOM element
        def analyze_report_element(element)
          element_report = Galaxy::TestSupport::DiagnosticsReportBuilder::ReportTable.new

          #information from Capybara
          ["text", "value", "visible?", "checked?", "selected?"].each do |attrib|
            if element.respond_to?(attrib)
              element_attribute = element.send(attrib)
              element_report.write_stats attrib, element_attribute unless element_attribute.blank?
            end
          end

          #information from Selenium
          ["tag_name", "location", "size"].each do |attrib|
            if (element.native.respond_to?(attrib))
              element_attribute = element.native.send(attrib)
              element_report.write_stats attrib, element_attribute unless element_attribute.blank?
            end
          end

          #information from Selenium that are common attributes
          ["id", "name", "class", "value", "href", "style", "type"].each do |attrib|
            element_attribute = get_attribute element, attrib
            element_report.write_stats attrib, element_attribute unless element_attribute.blank?
          end

          # information from Selenium that may not be available depending on the form, the full outerHTML of the element
          if (@test_object.respond_to?(:evaluate_script))
            element_id = get_attribute element, "id"
            unless (element_id.blank?)
              element_report.write_stats "outterHTML", @test_object.evaluate_script("$(\"\##{element_id}\")[0].outerHTML")
            end
          end
          element_report.write_stats "inspect", element.pretty_inspect

          element_report.full_table
        end

        def get_attribute(element, attribute)
          if element.native.respond_to?(:attribute)
            element.native.attribute(attribute)
          elsif element.native.respond_to?(:[])
            element.native[attribute]
          else
            nil
          end
        end
      end
    end
  end
end