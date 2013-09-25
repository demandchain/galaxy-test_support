module Galaxy
  module TestSupport
    class DiagnosticsReportBuilder
      MAX_OLD_FOLDERS = 10

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
          @full_table << "<div style=\"display: table-cell; font-weight: bold; vertical-align: top;\">#{label}</div>"
          @full_table << "<div style=\"display: table-cell;\">#{value}</div>"
          @full_table << "</div>"
        end

        def full_table
          close_table
          @full_table
        end
      end

      class << self
        def current_report
          @@current_report ||= DiagnosticsReportBuilder.new
        end

        def new_report
          @@current_report = DiagnosticsReportBuilder.new
        end
      end

      def close_report
        unless File.exists?(report_page_name)
          base_page
          File.open(report_page_name, "a") do |write_file|
            write_file.write(%Q[<p>No Errors to report</p>])
          end
        end
      end

      def report_folder_name
        unless @folder_name
          cleanup_old_folders

          if Dir.exists?(Rails.root.join("diagnostics_report/"))
            FileUtils.mv Rails.root.join("diagnostics_report/"),
                         Rails.root.join("diagnostics_report_#{DateTime.now.strftime("%Y_%m_%d_%H_%M_%S")}/")
          end

          @folder_name = Rails.root.join("diagnostics_report/")
          FileUtils.mkdir_p @folder_name
          base_page
        end

        @folder_name
      end

      # The system will only allow up to MAX_OLD_FOLDERS at a time
      # so it occasionally cleans up old folders so they don't get
      # too out of hand...
      def cleanup_old_folders
        old_directories = Dir[Rails.root.join("diagnostics_report_*")].each { |dir| Dir.exists?(dir) ? dir : nil }.compact
        if Array.wrap(old_directories).length > MAX_OLD_FOLDERS
          old_directories.each_with_index do |dir, index|
            return if index > old_directories.length - MAX_OLD_FOLDERS
            FileUtils.rm_rf dir
          end
        end
      end

      def base_page_name
        File.join(report_folder_name, "index.html")
      end

      def report_page_name
        File.join(report_folder_name, "report_contents.html")
      end

      def base_page()
        unless File.exists?(base_page_name)
          File.open(base_page_name, "a+") do |write_file|
            write_file.write(%Q[<html>
  <head>
    <title>Diagnostics report</title>
  </head>
  <body>
    <iframe src="report_contents.html" style="width: 100%; height:  100%; border:  0px; overflow:  scroll;"></iframe>
    <script src="http://ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js" ></script>
  </body>
</html>])
          end
        end
      end

      def within_section(section_text, &block)
        begin
          File.open(report_page_name, "a") do |write_file|
            write_file.write("<p>#{section_text}</p>")
            write_file.write("<div>")
          end
          block.yield self
        ensure
          File.open(report_page_name, "a") do |write_file|
            write_file.write("<div/>")
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

        "<img src=\"#{File.basename(dest_file_name)}\" />"
      end

      def page_dump(page_html)
        "<textarea style=\"width: 100%;\" rows=\"20\">#{CGI::escapeHTML(page_html)}</textarea>"
      end

      def page_link(page_html)
        dump_file_name = html_dump_file_name
        File.open(dump_file_name, "a+") do |dump_file|
          dump_file.write page_html
        end
        "<iframe src=\"#{dump_file_name}\" style=\"width: 100%; height: 500px;\"></iframe>"
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