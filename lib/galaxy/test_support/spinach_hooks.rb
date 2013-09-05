Spinach.hooks.on_failed_step do |step_data, exception, location, step_definitions|
  debug_failed_step("failed", step_data, exception, location, step_definitions)
end

Spinach.hooks.on_error_step do |step_data, exception, location, step_definitions|
  debug_failed_step("had an error", step_data, exception, location, step_definitions)
end

def debug_failed_step(failure_description, step_data, exception, location, step_definitions)
  puts("A step #{failure_description} at:")
  puts("  #{location[0]}:#{location[1]}")
  puts("")
  puts("In the step:")
  puts("  #{step_data.scenario}:") if step_data.scenario
  puts("  #{step_data.keyword} #{step_data.name}:#{step_data.line}")

  puts("")
  puts("The exception which was thrown is:")
  puts("  #{exception.to_s}")
  puts(exception.backtrace)

  puts("")
  puts("Step definition instance variables:")
  step_definitions.instance_variable_names.each do |name|
    puts("#{name} = #{step_definitions.send(:instance_variable_get, name).to_s}\n\n")
  end

  Galaxy::TestSupport::CapybaraDiagnostics.output_page_details("#{step_data.name}:#{step_data.line}")
end