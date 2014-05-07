require ::File.expand_path('file_asset', File.dirname(__FILE__))

module Galaxy
  module TestSupport
    class DiagnosticsReportBuilder
      MAX_OLD_FOLDERS = 5

      def self.escape_string value
        "".html_safe + value.to_s
      end

      def initialize(folder_name = "diagnostics_report")
        @parent_folder_name ||= "diagnostics_report"
        @base_folder_name   = folder_name
      end

      class ReportTable
        def initialize
          @full_table   = ""
          @table_closed = false
          open_table
        end

        def open_table
          @full_table << "<div class=\"test-support-table\">"
        end

        def close_table
          @full_table << "</div>" unless @table_closed
          @table_closed = true
        end

        # Writes information to the table.
        # Parameters:
        #   label             - The label for the information.
        #                       Should be short.  Will be made bold and the cell will be shrunk.
        #   value             - The value for the information.
        #                       If the value is very wide, the cell will expand to show it.
        #                       If the value is very tall, an expansion option will be provided, and the
        #                       cell will truncate the value otherwise.
        #   options:
        #     prevent_shrink  - default - false
        #                       If set, the cell will not be truncated if it is too tall, instead the cell will show
        #                       the full contents.
        def write_stats label, value, options = {}
          @full_table << "<div class=\"test-support-row\">"
          @full_table << "<div class=\"test-support-cell-label\">#{Galaxy::TestSupport::DiagnosticsReportBuilder.escape_string(label)}</div>"
          @full_table << "<div class=\"test-support-cell-expand\">"
          unless options[:prevent_shrink]
            @full_table << "<div class=\"hidden\"><a href=\"#\"><img src=\"expand.gif\"></a></div>"
          end
          @full_table << "</div>"
          @full_table << "<div class=\"test-support-cell-data\">"
          unless options[:prevent_shrink]
            @full_table << "<div class=\"hide-contents\">"
          end

          @full_table << "<pre><code>#{Galaxy::TestSupport::DiagnosticsReportBuilder.escape_string(value)}</code></pre>"
          unless options[:prevent_shrink]
            @full_table << "</div>"
            @full_table << "<div class=\"test-support-cell-more hidden\"><a href=\"#\">more...</a></div>"
          end
          @full_table << "</div>"
          @full_table << "</div>"
        end

        def full_table
          close_table
          @full_table.html_safe
        end
      end

      class << self
        def current_report(folder_name = "diagnostics_report")
          @@current_report ||= DiagnosticsReportBuilder.new(folder_name)
        end

        def new_report(folder_name = "diagnostics_report")
          @@current_report = DiagnosticsReportBuilder.new(folder_name)
        end
      end

      def close_report
        unless File.exists?(simple_report_page_name)
          base_page
          File.open(report_page_name, "a:UTF-8") do |write_file|
            write_file.write %Q[<p class=\"test-support-no-errors\">No Errors to report</p>]
            write_file.write "\n"
          end
        end
      end

      def report_folder_name
        unless @folder_name
          @folder_name = File.join(index_folder_name, "#{@base_folder_name}/")

          if Dir.exists?(report_folder_name)
            new_sub_dir = "#{@base_folder_name}_#{DateTime.now.strftime("%Y_%m_%d_%H_%M_%S")}/"
            FileUtils.mv report_folder_name,
                         File.join(index_folder_name, new_sub_dir)

            add_index_file "#{new_sub_dir}index.html"
            add_index_file "../coverage/index.html"
          end

          cleanup_old_folders

          FileUtils.mkdir_p @folder_name
          base_page
        end

        @folder_name
      end

      def index_folder_name
        unless @index_folder_name
          @index_folder_name = Rails.root.join("#{@parent_folder_name}/")

          cleanup_legacy_structure

          FileUtils.mkdir_p @index_folder_name
        end

        @index_folder_name
      end

      def cleanup_legacy_structure
        cleanup_legacy_folders @parent_folder_name
        cleanup_legacy_folders @base_folder_name

        cleanup_legacy_folders "diagnostics_report"
        cleanup_legacy_folders "diagnostics_rspec_report"
      end

      def cleanup_legacy_folders legacy_folder_name
        new_folder_name = index_folder_name
        FileUtils.mkdir_p new_folder_name

        if Dir.exists?(Rails.root.join("#{legacy_folder_name}/")) &&
            Dir[Rails.root.join("#{legacy_folder_name}/*")].map { |dir| File.directory?(dir) ? dir : nil }.compact.blank? &&
            !Dir[Rails.root.join("#{legacy_folder_name}/*")].map { |file| File.file?(file) ? file : nil }.compact.blank?
          if (@base_folder_name == legacy_folder_name)
            new_sub_dir = "#{legacy_folder_name}_#{DateTime.now.strftime("%Y_%m_%d_%H_%M_%S")}"
          else
            new_sub_dir = legacy_folder_name
          end
          full_sub_dir = File.join(index_folder_name, new_sub_dir)

          if (legacy_folder_name == @parent_folder_name)
            FileUtils.mkdir_p full_sub_dir
            Dir[Rails.root.join("#{legacy_folder_name}/*")].each do |file|
              unless file == full_sub_dir
                FileUtils.mv file, File.join(full_sub_dir, File.basename(file))
              end
            end
          else
            FileUtils.mv Rails.root.join("#{legacy_folder_name}/"), full_sub_dir
          end

          add_index_file "#{new_sub_dir}/index.html"
        end

        old_directories = Dir[Rails.root.join("#{legacy_folder_name}_*")].map { |dir| File.directory?(dir) ? dir : nil }.compact
        unless Array.wrap(old_directories).blank?
          old_directories.each do |dir|
            new_sub_dir = File.basename(dir)
            FileUtils.mv dir, File.join(index_folder_name, "#{new_sub_dir}")
            add_index_file "#{new_sub_dir}/index.html"
          end
        end
      end

      # The system will only allow up to MAX_OLD_FOLDERS at a time
      # so it occasionally cleans up old folders so they don't get
      # too out of hand...
      def cleanup_old_folders
        old_directories = Dir[File.join(index_folder_name, "#{@base_folder_name}_*")].
            map { |dir| File.directory?(dir) ? dir : nil }.compact
        if Array.wrap(old_directories).length > MAX_OLD_FOLDERS
          old_directories.each_with_index do |dir, index|
            return if index >= old_directories.length - MAX_OLD_FOLDERS
            remove_index_file "#{File.basename(dir)}/index.html"
            FileUtils.rm_rf dir
          end
        end
      end

      def base_page_name
        File.join(report_folder_name, "index.html")
      end

      def index_page_name
        File.join(index_folder_name, "index.html")
      end

      def create_style_sheet(html_file_name)
        css_name = File.join(File.dirname(html_file_name), "test-support.css")
        FileAsset.asset("test-support.css").add_file(css_name)
      end

      def simple_report_page_name
        File.join(report_folder_name, "report_contents.html")
      end

      def report_page_name
        page_name = simple_report_page_name
        FileAsset.asset("report_contents.html").add_file(page_name)
        report_support_files page_name
        page_name
      end

      def report_support_files(page_name)
        create_style_sheet(page_name)

        support_folder_name = File.dirname(page_name)
        FileAsset.asset("collapse.gif").add_file(File.join(support_folder_name, "collapse.gif"))
        FileAsset.asset("expand.gif").add_file(File.join(support_folder_name, "expand.gif"))
        FileAsset.asset("more_info.js").add_file(File.join(support_folder_name, "more_info.js"))
      end

      def index_report_page_name
        page_name = File.join(index_folder_name, "report_contents.html")
        FileAsset.asset("report_contents.html").add_file(page_name)
        create_style_sheet(page_name)
        page_name
      end

      def base_page()
        unless File.exists?(base_page_name)
          FileAsset.asset("base.html").create_file(base_page_name)
          add_index_file "#{@base_folder_name}/index.html"
        end
        create_style_sheet(base_page_name)
      end

      def index_page()
        FileAsset.asset("index.html").add_file(index_page_name)
        create_style_sheet(index_page_name)
      end

      def index_entry(file_name)
        "<a href=\"#{file_name}\" target=\"_blank\">#{file_name}</a><br />\n"
      end

      def add_index_file file_name
        index_page
        indexes = []
        if File.exists?(index_report_page_name)
          File.open(index_report_page_name, "r:UTF-8") do |read_file|
            indexes = read_file.readlines
          end
        end

        unless indexes.include? index_entry(file_name)
          indexes << index_entry(file_name)
        end
        indexes = indexes.reduce([]) do |reduce_map, value|
          reduce_map << value unless value.blank?
          reduce_map
        end
        indexes.sort!

        File.open(index_report_page_name, "w:UTF-8") do |write_file|
          indexes.each do |index_line|
            write_file.write index_line.to_s.force_encoding("UTF-8")
          end
        end
      end

      def remove_index_file file_name
        index_page
        indexes = []
        if File.exists?(index_report_page_name)
          File.open(index_report_page_name, "r:UTF-8") do |read_file|
            indexes = read_file.readlines
          end
        end

        indexes.delete index_entry(file_name)
        indexes = indexes.reduce([]) do |reduce_map, value|
          reduce_map << value unless value.blank?
          reduce_map
        end
        indexes.sort!

        File.open(index_report_page_name, "w:UTF-8") do |write_file|
          indexes.each do |index_line|
            write_file.write index_line.to_s.force_encoding("UTF-8")
          end
        end
      end

      def within_section(section_text, &block)
        begin
          File.open(report_page_name, "a:UTF-8") do |write_file|
            write_file.write "<p class=\"test-support-section-label\">#{Galaxy::TestSupport::DiagnosticsReportBuilder.escape_string(section_text)}</p>".
                                 force_encoding("UTF-8")
            write_file.write "\n"
            write_file.write "<div class=\"test-support-section\">"
            write_file.write "\n"
          end
          block.yield self
        ensure
          File.open(report_page_name, "a:UTF-8") do |write_file|
            write_file.write "<div/>"
            write_file.write "\n"
          end
        end
      end

      def within_table(&block)
        begin
          report_table = ReportTable.new
          block.yield report_table
        ensure
          File.open(report_page_name, "a:UTF-8") do |write_file|
            write_file.write report_table.full_table.force_encoding("UTF-8")
          end
        end
      end

      def image_link(image_file_name)
        dest_file_name = File.join(report_folder_name, File.basename(image_file_name))
        if File.exists?(dest_file_name)
          file_name, extension = File.basename(image_file_name).split "."
          file_number          = 1
          while File.exists?(dest_file_name)
            file_number    += 1
            dest_file_name = File.join(report_folder_name, "#{file_name}_#{file_number}.#{extension}")
          end
        end

        FileUtils.mv image_file_name, dest_file_name

        "<img class=\"test-support-section-image\" src=\"#{File.basename(dest_file_name)}\" />".html_safe
      end

      def page_dump(page_html)
        "<textarea class=\"test-support-page-dump\">#{Galaxy::TestSupport::DiagnosticsReportBuilder.escape_string(page_html)}</textarea>".html_safe
      end

      def page_link(page_html)
        dump_file_name = html_dump_file_name
        File.open(dump_file_name, "w:UTF-8") do |dump_file|
          dump_file.write page_html.to_s.force_encoding("UTF-8")
        end
        "<iframe src=\"#{File.basename(dump_file_name)}\" class=\"test-support-sample-frame\"></iframe>".html_safe
      end

      def formatted_backtrace(error)
        formatted_trace(error.backtrace)
      end

      def formatted_trace(backtrace_array)
        Galaxy::TestSupport::DiagnosticsReportBuilder.format_code_refs(
            backtrace_array.map { |value| Galaxy::TestSupport::DiagnosticsReportBuilder.escape_string (value) }.
                join("<br />\n").html_safe)
      end

      def self.format_code_refs(some_text)
        safe_text = Galaxy::TestSupport::DiagnosticsReportBuilder.escape_string(some_text)

        safe_text.gsub(/(#{Rails.root}|\.\/|(?=(?:^features|^spec)\/))([^\:\n]*\:[^\:\n ]*)/,
                       "\\1 <span class=\"test-support-app-file\">\\2\\3</span> ").html_safe
      end

      def html_dump_file_name
        dump_num = 1
        while File.exists?(File.join(report_folder_name, "html_dump_#{dump_num}.html"))
          dump_num += 1
        end

        File.join(report_folder_name, "html_dump_#{dump_num}.html")
      end

      def self.pretty_print_variable variable
        begin
          Galaxy::TestSupport::DiagnosticsReportBuilder.format_code_refs(variable.pretty_inspect)
        rescue
          Galaxy::TestSupport::DiagnosticsReportBuilder.format_code_refs(variable.to_s)
        end
      end
    end
  end
end