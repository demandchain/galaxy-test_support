# TestSupport

This GEM simply provides some diagnostic tools that I think will be useful when running tests.

## Installation

Add this line to your application's Gemfile:

    gem 'test_support', :git => "git@github.com:demandchain/test_support.git"

## Usage

### Automated Error Reporting

The gem has the ability to add hooks to Spinach or Cucumber which will generate a failure report when a feature fails.
The generated report will output as much information as the gem can determine about the failing step.  Examples
include:

* The HTML for the current page
* The URL for the current page
* A screen shot of the current page
* The instances variables of the test
* The error thrown
* The stack trace of the thrown error

To add the hooks for automated error reporting on step failure, simply add the following lines to the end
of the indicated file:

For RSpec:
    spec_helper.rb:  require "test_support/rspec_hooks"

For Spinach:
    env.rb:  require "test_support/spinach_hooks"

For Cucumber:
    env.rb:  require "test_support/cucumber_hooks"

### Finder analysis

Capybara has a class of functions which I call finders.  Examples of these functions are:

* all
* find
* within
* click_link

The basic purpose of the functions is to find an element on the form and possibly to perform an action once found.
Sometimes it can be hard to diagnose problems with these functions.  There are also some known problems with the
Selenium web driver which can cause it to have false negatives.

To address both of these issues, this Gem provides the function:  `test_finder`

To call this function on a finder function:

    sample_function_name sample_param_1, sample_param_2, sample_param_3...

You would make the following call:

    TestSupport::CapybaraDiagnostics.test_finder self, :sample_function_name, sample_param_1, sample_param_2, sample_param_3...

The test_finder function outputs all results into the same report as the automated step failure report.  It will
perform the following actions:

1. Run the function as if it were called directly.  If it works, no additional action will be performed.
2. Output the failure error and the stack trace.
3. Output some basic environmental information.
4. Output a diagnosis of the finder.  This diagnosis might include a list of all of the elements on the page
which match the find criteria, the most common attributes for the element, the size and placement of the element, etc.
5. Take a screenshot.
6. Retry the action via Capybara.
7. Retry the action via JavaScript.

The JavaScript retry is done as a workaround to a Selenium error which we were running into on some tests.  An
effective and unfortunately necessary hack.  It may not be necessary any more if Selenium has been updated and/or
fixed.  The good news is that if Selenium is fixed, it will not be called.

Most issues will probably be able to be resolved analyzing the HTML dumped using the automatic hooks.  Use the
test_finder function only if it is really needed.

#### Element diagnosis

Sometimes you aren't having a problem with the finder, yet something isn't working.  At times like that, it may be
nice to be able to see information about an element on the page.  To do this, you can output the finder analysis
directly:

    finder_info = TestSupport::CapybaraDiagnostics::FindAction.new(parent_object, :find, "#options")
    finder_info.generate_diagnostics_report "A label for the report"
    found_object = finder_info.run

### Logs

The system will try to automatically capture the last 500 lines of the log file when an exception occurs.  You can
configure the log capture process as follows:

To turn off the automatic grabbing of logs (default is true):

    TestSupport::Configuration.grab_logs = false

To adjust the number of lines fetched (default is 500 lines):

    TestSupport::Configuration.default_num_lines = 500

To add other log files:

    TestSupport::Configuration.add_log_file("..\other_project\logs\development.log", num_lines: 500)

The first parameter is the relative path of the log file from the project root.  You may also specify the
following options:

* num_lines - defaults to default_num_lines

## Development

You'll probably save yourself a lot of pain during development if you change the Gemfile line to this:

    gem 'test_support', '~> 0.0.6', :path => '../test_support'

## Reports

Reports for each error found are split into two halves:

* A minimal report half that is always shown
* A More Info report half that is hidden until the user wants to see it.

The idea is to have a quick view of the essential information for the error that is fairly short so that any
particular error you may be interested in can be found quickly and easily.

Once found, all of the detailed information for that error can then be found.  This will hopefully simplify finding
separate errors.  (When there is a lot of information, the boundry between one error and the next gets harder to find
 when scrolling.

### Configured Reports
Reports are generated using:  TestSupport::ConfiguredReport

To change the output order and/or information for a report, you can access the ConfiguredReport class for a report
using TestSupport::Configuration.report_configuration.  The following values can be passed in to get the
different report configurations:

* :rspec
* :cucumber
* :spinach

ConfiguredReport outputs an error report based on symbol based configurations

The configurations are as follows:
* min_fields
* more_info_fields
* expand_fields
* expand_inline_fields
* exclude_fields

#### min_field

This is a list of the fields which are to be output at the top of the report such that they are always visible. Items
 in the min list which cannot be found will output an error.

#### more_info_fields

This is a list of the fields which are to be output below the min fields in a section that is initially hidden.  The
user can expand these values If/when they need to. Items in the more info list which cannot be found will output an
error.

#### expand_fields

This is a list of the fields which are to be expanded when they are encountered. Expanded fields are shown in a
sub-table of values so that the instance variables are then each output.  Items which are to be expanded may be
explicitly or implicitly exported.  Items which are not encountered but are in the expand list will be ignored.

#### expand_inline_fields

This is a list of the fields which are to be expanded, but unlike expanded fields when these items are expanded,
they will be placed at the same level as the current items rather than in a sub-table.

#### exclude_fields

This is a list of the fields which are not to be output when they are encountered. There are many implicit ways to
output a field (such as the expanded fields). If a field is to be implicityly exported,
it will not be exported if it is in this list.  A field can always be explicitly exported.  Items not encountered but
 in the exclude list will be ignored.

#### field names

Field names follow a set pattern:

    <object_name>__<function_property_or_hash_name>

You can have as many following __<function_or_property_name> values as you need.

Examples:

* self.exception.backtrace would be specified as: :self__exception__backtrace
* self.my_hash[:my_key] would be specified as: :self__my_hash__my_key
* self.to_s would be specified as: :self__to_s

There are a handful of special conditions:

* if the last_line is to_s, the label that is output will not be to_s, but the previous item level
* :logs

This will output the logs using TestSupport::LogCapture.capture_logs
Unlike normal items, if there are no logs to export, this will not generate an error.

* :capybara_diagnostics

This will output Capybara infomration using TestSupport::CapybaraDiagnostics.output_page_detail_section.
NOTE:  This option requres a parameter be passed into the options for :diagnostics_name Unlike normal items,
if Capybara is not being used, this will not generate an error.

* instance_variables

This allows you to access the instance variables for an object.

self.instance_variable_get("@my_variable_name") would be specified as: self__instance_variables__my_variable_name

self.instance_variables can be used to output all instance variables.

if self.instance_variables is placed in the expand option, the instance variables and their values will be placed in
a sub-table. Unlike normal items, if there are no instance variables, this will not generate an error.


Each report has a different set of objects that they pass into the report:
* rspec - self
* cucumber - self, scenario
* spinach - failure_description, step_data, exception, location, step_definitions, running_scenario

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request