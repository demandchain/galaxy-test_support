module Galaxy
  module TestSupport
    class CapybaraDiagnostics
      def self.output_page_details(screenshot_name)
        my_page = Capybara.current_session
        if (my_page)
          puts("page.url: #{my_page.current_url}") if my_page.try(:current_url)

          if my_page.respond_to?(:html)
            puts("Page HTML:")
            puts(my_page.html)
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

            browser.save_screenshot(filename)
            puts("Saved screen shot: #{filename}")
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
        FindAction.new(test_object, function_name, args).run
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
        def initialize(test_object, function_name, args)
          @test_object   = test_object
          @function_name = function_name
          @args          = args
        end

        def run
          begin
            @test_object.send(@function_name, *@args)
          rescue
            puts("An error occurred while processing \"#{@function_name.to_s}\":")
            puts("  #{$!.to_s}")
            puts("    #{$!.backtrace.join("\n    ")}")

            output_basic_details
            output_finder_details

            #screen_shot_dir = ::Rails.root.join "tmp/screen_shots"
            #FileUtils.mkdir_p(screen_shot_dir)
            #screenshot_name = File.join(screen_shot_dir, "#{DateTime.now.strftime("%Y_%m_%d")}_failure_#{SecureRandom.uuid}.png")
            #Capybara.current_session.save_screenshot screenshot_name
            #
            #puts("\n\nscreenshot: #{screenshot_name}")
            #puts("page.url: #{Capybara.current_session.current_url}")
            #puts("page.html:")
            #puts(Capybara.current_session.html)

            return @return_value if retry_action_with_found_element
            return @return_value if alternate_action_with_found_element

            raise $!
          end
        end

        # Dump the arguments to the function to the console for analysis.
        def output_basic_details
          puts("\nFunction: #{@function_name.to_s}")
          puts("Dumping args:")

          search_args.each_with_index do |the_arg, arg_index|
            puts("  [#{arg_index}] = #{dump_value(the_arg)}#{(arg_index == 0 && @args[0] != the_arg) ? " (guessed)" : nil}")
          end
          if options
            options.each do |key, value|
              puts("  #{key}: #{dump_value(value)}")
            end
          end

          puts("\nEnvironment information:")
          puts("  Window Height : #{Capybara.current_session.driver.evaluate_script("window.innerHeight")}")
          puts("  Window Width  : #{Capybara.current_session.driver.evaluate_script("window.innerWidth")}")
        end

        # Output some hopefully diagnostically useful information about the item being
        # searched for.
        #
        # Start by trying to use all to find all instances, even if hidden.
        # This may help identify why the right one isn't being found.
        def output_finder_details
          puts("\nAnalyzing finder for #{@function_name}...")

          if guessed_types.length > 1
            puts ("  Alternate possible types:")
            guessed_types.each do |guessed_type|
              puts ("    #{guessed_type}")
            end
          end

          all_page_elements = Capybara.current_session.all(*search_args, visible: false)
          puts("  Found #{all_elements.length} items.")
          all_elements.each_with_index do |element, element_index|
            analyze_report_element(element, element_index)
          end

          if (all_elements.length != all_page_elements.length)
            all_other_elements = all_page_elements - all_elements
            puts("  Found #{all_other_elements.length} items elsewhere on the page:")
            all_other_elements.each_with_index do |element, element_index|
              analyze_report_element(element, element_index)
            end
          end
        end

        def retry_action_with_found_element
          if found_element
            begin
              puts("  Trying action manually...")

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
                  puts("    Could not decide what to do with #{@function_name}")
                  raise new Exception("unknown action")
              end

              return true
            rescue
              puts "    Still couldn't do the action - #{$!.to_s}."
            end
          end

          false
        end

        def alternate_action_with_found_element
          if found_element
            begin
              native_id = found_element.native.attribute("id")
              if (native_id)
                puts("  Trying action through JScript...")
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
                    puts("    Could not decide what to do with #{@function_name}")
                    raise new Exception("unknown action")
                end

                return true
              end
            rescue
              puts "    Still couldn't do the action - #{$!.to_s}."
            end
          end

          false
        end

        def found_element
          if all_elements && all_elements.length == 1
            all_elements[0]
          else
            nil
          end
        end

        def all_elements
          unless @all_elements
            if options && options.has_key?(:from)
              from_within = FindAction.new(@test_object, :find, [:select, options[:from]])
              from_within.output_basic_details
              from_within.output_finder_details
              from_element = from_within.found_element

              unless from_element
                puts "  Could not find the selection combo #{options[:from]}"
                @all_elements = []
                return @all_elements
              end
            else
              from_element = @test_object
            end

            @all_elements = from_element.all(*search_args, visible: false)
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
        def analyze_report_element(element, element_index)
          puts("    Element [#{element_index}]")

          #information from Capybara
          ["text", "value", "visible?", "checked?", "selected?"].each do |attrib|
            if element.respond_to?(attrib)
              element_attribute = element.send(attrib)
              puts("      #{attrib}#{" " * (10 - attrib.length)} = #{element_attribute}") unless element_attribute.blank?
            end
          end

          #information from Selenium
          ["tag_name", "location", "size"].each do |attrib|
            if (element.native.respond_to?(attrib))
              element_attribute = element.native.send(attrib)
              puts("      #{attrib}#{" " * (10 - attrib.length)} = #{element_attribute}") unless element_attribute.blank?
            end
          end

          #information from Selenium that are common attributes
          ["id", "name", "class", "value", "href", "style", "type"].each do |attrib|
            element_attribute = element.native.attribute(attrib)
            puts("      #{attrib}#{" " * (10 - attrib.length)} = #{element_attribute}") unless element_attribute.blank?
          end

          # information from Selenium that may not be available depending on the form, the full outerHTML of the element
          element_id = element.native.attribute("id")
          unless (element_id.blank?)
            puts("      outterHTML = #{@test_object.evaluate_script("$(\"\##{element_id}\")[0].outerHTML")}")
          end
        end
      end
    end
  end
end