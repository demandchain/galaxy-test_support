require ::File.expand_path('file_asset', File.dirname(__FILE__))

module Galaxy
  module TestSupport
    class DiagnosticsReportBuilder
      MAX_OLD_FOLDERS = 5

      def self.escape_string value
        if value.html_safe?
          value
        else
          CGI::escapeHTML(value)
        end
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
          @full_table << "<div style=\"display: table; width: 100%; \">"
        end

        def close_table
          @full_table << "</div>" unless @table_closed
          @table_closed = true
        end

        def write_stats label, value
          @full_table << "<div style=\"display: table-row;\">"
          @full_table << "<div style=\"display: table-cell; font-weight: bold; vertical-align: top;\">#{Galaxy::TestSupport::DiagnosticsReportBuilder.escape_string(label)}</div>"
          @full_table << "<div style=\"display: table-cell;\">#{Galaxy::TestSupport::DiagnosticsReportBuilder.escape_string(value)}</div>"
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
        unless File.exists?(report_page_name)
          base_page
          File.open(report_page_name, "a") do |write_file|
            write_file.write %Q[<p>No Errors to report</p>]
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

      def report_page_name
        File.join(report_folder_name, "report_contents.html")
      end

      def index_report_page_name
        File.join(index_folder_name, "report_contents.html")
      end

      def base_page()
        unless File.exists?(base_page_name)
          FileAsset.asset("index.html").create_file(base_page_name)
          add_index_file "#{@base_folder_name}/index.html"
        end
      end

      def index_page()
        unless File.exists?(index_page_name)
          FileAsset.asset("index.html").create_file(index_page_name)
        end
      end

      def index_entry(file_name)
        "<a href=\"#{file_name}\" target=\"_blank\">#{file_name}</a><br />\n"
      end

      def add_index_file file_name
        index_page
        indexes = []
        if File.exists?(index_report_page_name)
          File.open(index_report_page_name, "r") do |read_file|
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

        File.open(index_report_page_name, "w") do |write_file|
          indexes.each do |index_line|
            write_file.write index_line
          end
        end
      end

      def remove_index_file file_name
        index_page
        indexes = []
        if File.exists?(index_report_page_name)
          File.open(index_report_page_name, "r") do |read_file|
            indexes = read_file.readlines
          end
        end

        indexes.delete index_entry(file_name)
        indexes = indexes.reduce([]) do |reduce_map, value|
          reduce_map << value unless value.blank?
          reduce_map
        end
        indexes.sort!

        File.open(index_report_page_name, "w") do |write_file|
          indexes.each do |index_line|
            write_file.write index_line
          end
        end
      end

      def within_section(section_text, &block)
        begin
          File.open(report_page_name, "a") do |write_file|
            write_file.write "<p>#{Galaxy::TestSupport::DiagnosticsReportBuilder.escape_string(section_text)}</p>"
            write_file.write "\n"
            write_file.write "<div>"
            write_file.write "\n"
          end
          block.yield self
        ensure
          File.open(report_page_name, "a") do |write_file|
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
          File.open(report_page_name, "a") do |write_file|
            write_file.write report_table.full_table
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

        "<img src=\"#{File.basename(dest_file_name)}\" />".html_safe
      end

      def page_dump(page_html)
        "<textarea style=\"width: 100%;\" rows=\"20\">#{Galaxy::TestSupport::DiagnosticsReportBuilder.escape_string(page_html)}</textarea>".html_safe
      end

      def page_link(page_html)
        dump_file_name = html_dump_file_name
        File.open(dump_file_name, "w") do |dump_file|
          dump_file.write page_html
        end
        "<iframe src=\"#{dump_file_name}\" style=\"width: 100%; height: 500px;\"></iframe>".html_safe
      end

      def formatted_backtrace(error)
        formatted_trace(error.backtrace)
      end

      def formatted_trace(backtrace_array)
        backtrace_array.map { |value| CGI::escapeHTML(value) }.
            join("<br />").gsub(/(#{Rails.root})([^\:]*\:[^\:]*)/, "\\1 <b>\\2</b> ").html_safe
      end

      def html_dump_file_name
        dump_num = 1
        while File.exists?(File.join(report_folder_name, "html_dump_#{dump_num}.html"))
          dump_num += 1
        end

        File.join(report_folder_name, "html_dump_#{dump_num}.html")
      end
    end
  end
end