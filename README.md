# Galaxy::TestSupport

This GEM simply provides some diagnostic tools that I think will be useful when running tests.

## Installation

Add this line to your application's Gemfile:

    gem 'galaxy-test_support', :git => "git@github.com:demandchain/galaxy-test_support.git"

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
    spec_helper.rb:  require "galaxy/test_support/rspec_hooks"

For Spinach:
    env.rb:  require "galaxy/test_support/spinach_hooks"

For Cucumber:
    env.rb:  require "galaxy/test_support/cucumber_hooks"

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
    Galaxy::TestSupport::CapybaraDiagnostics.test_finder self, :sample_function_name, sample_param_1, sample_param_2, sample_param_3...

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

## Development

You'll probably save yourself a lot of pain during development if you change the Gemfile line to this:

    gem 'galaxy-test_support', '~> 0.0.6', :path => '../galaxy-test_support'

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request