require ::File.expand_path('configuration', File.dirname(__FILE__))
require ::File.expand_path('diagnostics_report_builder', File.dirname(__FILE__))

module Galaxy
  module TestSupport
    class LogCapture
      class << self
        TAIL_BUF_LENGTH = 1 << 16

        # This function will capture the logs and output them to the report
        def capture_logs(report_table = nil)
          if report_table
            log_folder = Rails.root.to_s
            if (log_folder =~ /\/features\/?$/ || log_folder =~ /\/spec\/?$/)
              log_folder = File.join(log_folder, "../")
            end

            default_log_file = "log/#{Rails.env.to_s}.log"

            output_log_file(report_table, File.join(log_folder, default_log_file))
            Galaxy::TestSupport::Configuration.user_log_files.each do |relatvive_log_file, options|
              output_log_file(report_table, File.join(log_folder, relatvive_log_file), options)
            end
          else
            Galaxy::TestSupport::DiagnosticsReportBuilder.current_report.within_section("Log Dump:") do |report|
              report.within_table do |new_report_table|
                Galaxy::TestSupport::LogCapture.capture_logs new_report_table
              end
            end
          end
        end

        def highlight_log_output(log_text)
          output_text = Galaxy::TestSupport::DiagnosticsReportBuilder.format_code_refs(log_text)
          output_text = output_text.gsub(/^(Completed 4.*)$/, "<span class=\"completed-error\">\\1<\/span>")
          output_text = output_text.gsub(/^(Completed [^4].*)$/, "<span class=\"completed-other\">\\1<\/span>")

          output_text.html_safe
        end

        # A cheap and sleazy tail function, but it should work...
        def output_log_file(report_table, log_file_name, options = {})
          output_file = false

          begin
            options.reverse_merge!({ num_lines: Galaxy::TestSupport::Configuration.num_lines })

            num_lines  = options[:num_lines] || Galaxy::TestSupport::Configuration.num_lines
            num_lines  = Galaxy::TestSupport::Configuration.num_lines if num_lines <= 0
            log_buffer = ""
            file_size  = File.size(log_file_name)

            File.open(log_file_name) do |log_file|
              seek_len = [file_size, TAIL_BUF_LENGTH].min
              log_file.seek -seek_len, IO::SEEK_END

              while (log_buffer.count("\n") <= num_lines)
                log_buffer = log_file.read(seek_len) + log_buffer

                file_size -= seek_len
                seek_len  = [file_size, TAIL_BUF_LENGTH].min

                break if seek_len <= 0

                log_file.seek -seek_len - TAIL_BUF_LENGTH, IO::SEEK_CUR
              end
            end

            if log_buffer
              log_buffer = log_buffer.split("\n")
              if (log_buffer.length > num_lines)
                log_buffer = log_buffer[-num_lines..-1]
              end

              report_table.write_stats File.basename(log_file_name),
                                       Galaxy::TestSupport::LogCapture.highlight_log_output(
                                           "log_file - #{log_file_name}:#{file_size}\n#{log_buffer.join("\n")}")

              output_file = true
            end
          rescue => error
            # Probably shouldn't do this, but I want to ignore any errors.
            # puts("error = #{error}")
          end

          output_file
        end
      end
    end
  end
end