After do |scenario|
  begin
    if scenario.failed?
      Galaxy::TestSupport::CapybaraDiagnostics.output_page_details(scenario.file_colon_line)
    end
  rescue
    puts("Could not save screen-shot")
  end
end