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

#### Element diagnosis

Sometimes you aren't having a problem with the finder, yet something isn't working.  At times like that, it may be
nice to be able to see information about an element on the page.  To do this, you can output the finder analysis
directly:

    finder_info = Galaxy::TestSupport::CapybaraDiagnostics::FindAction.new(parent_object, :find, "#options")
    finder_info.generate_diagnostics_report "A label for the report"
    found_object = finder_info.run

### Logs

The system will try to automatically capture the last 500 lines of the log file when an exception occurs.  You can
configure the log capture process as follows:

To turn off the automatic grabbing of logs (default is true):

    Galaxy::TestSupport::Configuration.grab_logs = false

To adjust the number of lines fetched (default is 500 lines):
s
    Galaxy::TestSupport::Configuration.default_num_lines = 500

To add other log files:

    Galaxy::TestSupport::Configuration.add_log_file("..\other_project\logs\development.log", num_lines: 500)

The first parameter is the relative path of the log file from the project root.  You may also specify the
following options:

* num_lines - defaults to default_num_lines

## Development

You'll probably save yourself a lot of pain during development if you change the Gemfile line to this:

    gem 'galaxy-test_support', '~> 0.0.6', :path => '../galaxy-test_support'

## Reports

*Incomplete*
This is a work in progress, but I am working on a way to configure and customize reports a little.

Reports for each error found are split into two halves:

* A minimal report half that is always shown
* A More Info report half that is hidden until the user wants to see it.

The idea is to have a quick view of the essential information for the error that is fairly short so that any
particular error you may be interested in can be found quickly and easily.

Once found, all of the detailed information for that error can then be found.  This will hopefully simplify finding
separate errors.  (When there is a lot of information, the boundry between one error and the next gets harder to find
 when scrolling.

### Configured Reports
Reports are generated using:  Galaxy::TestSupport::ConfiguredReport

To change the output order and/or information for a report, you can access the ConfiguredReport class for a report
using Galaxy::TestSupport::Configuration.report_configuration.  The following values can be passed in to get the
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

This will output the logs using Galaxy::TestSupport::LogCapture.capture_logs
Unlike normal items, if there are no logs to export, this will not generate an error.

* :capybara_diagnostics

This will output Capybara infomration using Galaxy::TestSupport::CapybaraDiagnostics.output_page_detail_section.
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

/Users/elittell/.rvm/rubies/ruby-1.9.3-p327/bin/ruby -e at_exit{sleep(1)};$stdout.sync=true;$stderr.sync=true;load($0=ARGV.shift) /Users/elittell/.rvm/gems/ruby-1.9.3-p327@homerun/gems/ruby-debug-ide-0.4.23.beta1/bin/rdebug-ide --disable-int-handler --port 49781 --dispatcher-port 49782 -- /Users/elittell/.rvm/gems/ruby-1.9.3-p327@homerun/bin/rspec /Users/elittell/Deem/code/galaxy-test_support/spec/pretty_formatter_spec.rb --require teamcity/spec/runner/formatter/teamcity/formatter --format Spec::Runner::Formatter::TeamcityFormatter --example Galaxy::TestSupport::PrettyFormatter
Testing started at 7:48 PM ...
Fast Debugger (ruby-debug-ide 0.4.23.beta1, ruby-debug-base19x 0.11.30.pre15) listens on 127.0.0.1:49781
[deprecated] I18n.enforce_available_locales will default to true in the future. If you really want to skip validation of your locale you can set I18n.enforce_available_locales = false to avoid this message.
@seed_value = 491524245855421995996088823893953334214
@seed_value = 601710713813126557211133152009112599813
@seed_value = 392638291173663621888078833850341577338
@seed_value = 848825681962392518341954012382976684309
@seed_value = 728624039625909300985043038811616738290
@seed_value = 694736175122188651334285981665058124017
@seed_value = 656513367713012652078367314082301409966
@seed_value = 137501212717904988212576905487500495295
@seed_value = 688879235694767118479026094627512867422
@seed_value = 872998308631126439597164005977839298519
@seed_value = 266739976121606389709427999559614406320
@seed_value = 179254151146477044793911692555125504765
@seed_value = 564566473177492606006198364634317430298
@seed_value = 707840195718786097986625232154516111746
@seed_value = 753413936358758993919490936506469032473
@seed_value = 394494948454642286490762827222974529643
@seed_value = 810875952790397455806297819832566603571
@seed_value = 805712765545945107130923146909803236058
@seed_value = 483430115339637051751482996141447855840
@seed_value = 845095249012300944339962195715480659233
@seed_value = 883880846076160119739877297127634163029
@seed_value = 551213485369299558668611792903971400895
@seed_value = 728048721121676799271329141732406891996
@seed_value = 752793533387566300854420133417087213192
@seed_value = 393336438470126554073385619274950069550
@seed_value = 335409686947454163956502712535604100321
@seed_value = 338274445850862609242494224423762090229
@seed_value = 330885639394992503866430514747392709976
@seed_value = 293911399411625540474840803539725410985
@seed_value = 502769016018698077614927672232102261478
@seed_value = 117415070909301361143493668441383050017
@seed_value = 263114211936449165579175154297257116248
@seed_value = 581444551557043139941839007085819930297
@seed_value = 812178369601134954721252112144404333383
@seed_value = 628191814246887064677060893319379361243
@seed_value = 120270196895450922569596330222378675874
@seed_value = 629149831575450335555521292453511669250
@seed_value = 453542386375918413261969128984425298780
@seed_value = 663747295376856378122176117462967290484

expected: == "#<@repellendus\n  \"Sit ipsa harum laborum animi exercitationem aliquid. #\\\\+%>&}{voluptatem\" = \"Iusto tempore pariatur sint autem et corrupti.\",\n  \"Laudantium delectus vel adipisci.\" =\n    [\n      {\n        \"Molestiae ut suscipit delectus beatae non.\" =>\n          [\n            174436974691.5453,\n            973061540.881479\n          ],\n        \"Reprehenderit eum quae ullam quis quo et magnam velit.\" =>\n          [\n            \"Beatae hic aut repudiandae voluptas ipsa. ~@+_^#}#]eos\"\n          ],\n        \"Explicabo numquam amet nesciunt quo natus mollitia ut. '?_%/&`<accusamus\" =>\n          {\n            :exercitationem => @quia?,\n            \"Quia impedit atque ipsa quae ut et neque maiores. #/@>=$ut\" => @quam?,\n            :ut => provident\n          }\n      }\n    ],\n  \"Adipisci inventore qui ut nihil ex ut. %_~-?molestiae\" =\n    {\n      \"Dolorum quod quo voluptate molestias impedit.\" =>\n        [\n          \"Architecto minus repellat et ut. []\\\\/(`^<$\\\\officiis\",\n          \"Accusantium magni pariatur vitae voluptate. <^_*#)}aut\"\n        ],\n      \"Dignissimos laborum cumque est aut et maiores. =?~>#<+*$assumenda\" =>\n        [\n          \"Dolorem corporis dolorem enim quia consequuntur. `_'@(>~^}in\",\n          \"A ex laboriosam explicabo ut.\",\n          Et rerum ad molestiae nesciunt at.\n        ]\n    }\n>"
     got:    "#<@repellendus         \"Sit ipsa harum laborum animi exercitationem aliquid. #\\\\+%>&}{voluptatem\" \n =\n\n \n  \n \n\n \n\n\n \n\"Iusto tempore pariatur sint autem et corrupti.\",  \n\n  \n  \n\n\n\"Laudantium delectus vel adipisci.\" =         \n\n [      \n    {\n \n\n \n\n\n     \n  \n\"Molestiae ut suscipit delectus beatae non.\"\n\n\n \n\n\n\n\n\n=>\n \n\n\n    \n  \n  [\n\n  \n \n\n    \n   \n174436974691.5453, \n \n \n\n\n    \n  973061540.881479], \n\n  \n \"Reprehenderit eum quae ullam quis quo et magnam velit.\"\n \n\n\n=> \n\n\n \n[\n\n\n\n\n\n  \n\"Beatae hic aut repudiandae voluptas ipsa. ~@+_^#}#]eos\"], \n \n   \"Explicabo numquam amet nesciunt quo natus mollitia ut. '?_%/&`<accusamus\"\n\n\n \n\n\n\n\n =>       {  \n\n   \n\n\n :exercitationem\n \n\n\n\n\n \n\n  \n    \n=>\n\n\n \n \n \n   \n@quia?,\n \n\n       \n\n \"Quia impedit atque ipsa quae ut et neque maiores. #/@>=$ut\"        \n =>\n\n\n\n\n \n\n\n@quam?,     \n \n \n  :ut \n\n\n\n\n\n=> \n \n \n\n\n\n\n\n\n provident}}],\n \n\n\n \n\n \n\n\n\n      \"Adipisci inventore qui ut nihil ex ut. %_~-?molestiae\" \n\n\n  \n \n \n  \n \n \n\n=\n\n    \n\n{\n    \n   \"Dolorum quod quo voluptate molestias impedit.\" \n\n\n \n\n  \n=> \n   \n   \n [\n\n\n\n\n\n \n\n\"Architecto minus repellat et ut. []\\\\/(`^<$\\\\officiis\",\n\n \"Accusantium magni pariatur vitae voluptate. <^_*#)}aut\"],\n\n \n\"Dignissimos laborum cumque est aut et maiores. =?~>#<+*$assumenda\"\n  \n =>  \n\n[ \n  \n \n \n \n\"Dolorem corporis dolorem enim quia consequuntur. `_'@(>~^}in\",\n  \n      \n\n \"A ex laboriosam explicabo ut.\", \n\n\n\n\n\n\n\n\nEt rerum ad molestiae nesciunt at.]}>"
./spec/pretty_formatter_spec.rb:74:in `block (3 levels) in <top (required)>'
-e:1:in `load'
-e:1:in `<main>'
@seed_value = 147515312093665341108600810662105000454
@seed_value = 269489625859250610975943264550654609036
@seed_value = 249770444410488409071615459678716098046
@seed_value = 501416116820940262033170881523178042254
@seed_value = 377376564710538610153000958363964542780
@seed_value = 501512544986250886743833540862971361251
@seed_value = 163901498192012915324578162154151488855
@seed_value = 879778704762246682348281869148826829471
@seed_value = 573761720956993929694010134009260894633
@seed_value = 486322636186295107704429868425789401921
@seed_value = 573499135778050799722837246201557378515
@seed_value = 794054839847918719399600249495283350222
@seed_value = 153213452223220406902309056779883945156

expected: == "#<@non\n  \"Et est quia itaque tempore. }~`_\\\\{/*earum\" = \"Et deleniti et eum. +#<{~)&#nemo\",\n  \"Rerum sed quis sequi quo et ut aut.\" =\n    #<@maiores?\n      \"Eligendi vero possimus illo. `#%=/(<$!+inventore\" =\n        #<@voluptatem\n          \"Ipsum illum sint possimus et dolorem ex debitis. %^@](>`/ipsum\" = \"Nobis velit nostrum quisquam. {/'\\\\?aut\",\n          @atque = \"Exercitationem quo sed unde similique earum eum.\"\n        >\n    >,\n  @odio =\n    {\n      \"Tempore omnis dolores aliquam sequi commodi.\" =>\n        #<reiciendis?\n          rerum? = 2088-04-10T22:36:03-07:00,\n          nihil = \"Ipsa asperiores ut quo non.\"\n        >,\n      quam:\n        #<aut>,\n      consequatur: repellendus\n    }\n>\n\nSequi laborum sed odio enim ad quo.Veritatis dolores voluptas deserunt praesentium aperiam ut.\n  #<et?\n    \"Ut et consequatur non voluptatem ea. #_$>'hic\" =\n      {\n        porro:\n          #<voluptatibus>\n      },\n    \"Est non et quidem. $*+>}\\\"?architecto\" =\n      [\n        {\n          animi: \"Cupiditate voluptatem officia qui qui quisquam.\",\n          autem: \"Animi est ipsam ut qui aut nesciunt sit.\",\n          laudantium: 2041-02-13\n        },\n        \"Quis tempora aut error omnis voluptates.\",\n        #<tenetur?\n          \"Nisi nam et consequuntur voluptatem. >\#@+'`~^%possimus\" = \"Dolores atque est fuga et minus et. +'-*~\\\\(`$dolorem\"\n        >\n      ]\n  >"
     got:    "#<@non   \"Et est quia itaque tempore. }~`_\\\\{/*earum\" \n =\n\n\n\n\n \n\n\n\n\n\"Et deleniti et eum. +#<{~)&#nemo\",\n \"Rerum sed quis sequi quo et ut aut.\" \n\n \n\n \n  \n\n\n\n \n =         #<@maiores?    \"Eligendi vero possimus illo. `#%=/(<$!+inventore\"\n\n\n\n   \n\n\n \n\n  \n=  \n\n\n\n#<@voluptatem \"Ipsum illum sint possimus et dolorem ex debitis. %^@](>`/ipsum\" \n   \n\n\n \n\n  \n   \n\n=\n\n\n\n \n\n \n\n \n\n\"Nobis velit nostrum quisquam. {/'\\\\?aut\", \n\n \n\n\n     \n\n @atque  \n= \n \n \n \n\n\n \n\n\n\n  \"Exercitationem quo sed unde similique earum eum.\">>, \n\n       @odio\n\n\n\n\n\n \n\n\n=\n \n\n \n \n\n\n {  \n\n\"Tempore omnis dolores aliquam sequi commodi.\"       => \n\n   \n\n \n\n  \n\n\n #<reiciendis?    rerum? \n =  \n  \n\n  2088-04-10T22:36:03-07:00,   \n  \n\n\n\n\n \n\n  \n\n nihil\n\n \n\n\n\n\n \n\n\n=  \n\n\n\n\n \"Ipsa asperiores ut quo non.\">,\n\n\n\n\n\n\n quam:\n\n  \n\n\n\n\n \n\n#<aut     >,\n\n\n\n\n \n\n\n \n \nconsequatur:  \n \n repellendus}>\nSequi laborum sed odio enim ad quo.Veritatis dolores voluptas deserunt praesentium aperiam ut.\n\n\n  \n \n#<et?          \"Ut et consequatur non voluptatem ea. #_$>'hic\"\n\n   \n=\n  \n\n\n\n\n  {\n\n  \n\n\n\n\nporro:          #<voluptatibus    >},  \n \n\"Est non et quidem. $*+>}\\\"?architecto\"     =\n   \n\n\n  \n \n[ \n   \n\n\n \n\n { \n\n \n \n \n\n \n \nanimi:       \"Cupiditate voluptatem officia qui qui quisquam.\", \n\n   \n  \n\n  \n\n\n\n autem:\n\n\n\n \n\n\n\n\"Animi est ipsam ut qui aut nesciunt sit.\",\n     \n\n\n   \n \n laudantium: \n\n \n \n2041-02-13},\n\n\n \"Quis tempora aut error omnis voluptates.\",         \n#<tenetur?     \"Nisi nam et consequuntur voluptatem. >\#@+'`~^%possimus\"\n\n\n\n\n\n    \n=\n\n\n\n\n\n\n\n\n \"Dolores atque est fuga et minus et. +'-*~\\\\(`$dolorem\">]>"
./spec/pretty_formatter_spec.rb:74:in `block (3 levels) in <top (required)>'
-e:1:in `load'
-e:1:in `<main>'
@seed_value = 813457072597866756848221145557146764285
@seed_value = 310610306815393969151481460055214550785
@seed_value = 839644645348310620689468532354627458297
@seed_value = 364183374513610752897813184441666372014
@seed_value = 113090128246491313697615215894024852198
@seed_value = 361320206826584327211447588980455212932
@seed_value = 408199311828555652879725877333931791747
@seed_value = 800656625058520016026882858955778534289
@seed_value = 546523893266600341954279164460557335218
@seed_value = 550556360912922512115973036414719504857
@seed_value = 101125204405795612263849122019062843821
@seed_value = 858089007513967400993173047742340353136
@seed_value = 393547675641787876030693621827571605989
@seed_value = 672865461892844650803465569213519143023
@seed_value = 268748138290985512749236207780137672122
@seed_value = 803739002038356811952075434067790769253
@seed_value = 185800771794661969075329928957519547704
@seed_value = 733277653806165300551195190813281734957
@seed_value = 772724570579272334522586317622896947545
@seed_value = 135067943014105606705746398456933771415
@seed_value = 186641092344152555554930509421152222703
@seed_value = 659310116658858373174342959709725074652
@seed_value = 438060572564034545604370800306191512165
@seed_value = 151990063309224038030431116167708601933
@seed_value = 836120141652850856064033779135929459799
@seed_value = 127760886041984207622988093040722394129
@seed_value = 562089134522865227032181697362250826944
@seed_value = 613100057297036068881969445194846443631
@seed_value = 566569370342389722500058701677312042152
@seed_value = 710018952625487591018759615189309644676
@seed_value = 307248711408428228369837974440508565187
@seed_value = 146697251952926901597975429486427947954

expected: == "#<@cumque\n  eius =\n    {\n      \"Porro qui cupiditate nam.\" =>\n        {\n          :et => \"Rerum et at corporis fuga impedit.\"\n        }\n    },\n  temporibus =\n    {\n      \"Enim voluptates consequuntur voluptas molestias suscipit quaerat consequatur assumenda. -#<&*_quos\" => \"Consectetur ab neque non sunt autem. =@~&`/sunt\"\n    },\n  @voluptatibus =\n    [\n      #<@in?\n        \"Eaque quis accusamus qui.\" =\n          [\n            exercitationem,\n            \"Voluptatibus nam deserunt exercitationem incidunt molestiae perferendis.\",\n            quasi\n          ],\n        \"Qui consectetur similique vel perspiciatis quo ea consequatur ut.\" =\n          #<@tenetur\n            \"Consectetur neque ad eaque voluptas et placeat labore nihil. @`-/=$suscipit\" = modi\n          >,\n        \"Ipsam voluptates dolor consequuntur eos ab.\" =\n          {\n            \"Eligendi dolores nobis aut voluptas sunt. =\\\\-*~!?possimus\" => @id?,\n            \"Rem ea maiores adipisci veniam voluptatem quis. +*)]{dolores\" => 2161-01-28T07:55:25-07:00\n          }\n      >\n    ]\n>"
     got:    "#<@cumque         eius      \n  = \n\n\n\n  {\n\n  \n\n   \n\n\n  \"Porro qui cupiditate nam.\"  \n\n\n  \n\n\n   => \n \n      \n {\n\n\n\n\n\n \n\n :et \n\n\n \n \n\n\n\n=>\n \n\n  \n\n\n \n\n\n\"Rerum et at corporis fuga impedit.\"}},\n\n\n \n\n\n\n\n\n \n temporibus\n  \n\n    \n\n \n\n \n  =\n    \n{\n\n\n\n \n \n   \n \"Enim voluptates consequuntur voluptas molestias suscipit quaerat consequatur assumenda. -#<&*_quos\" \n \n\n\n\n   \n \n\n \n => \n\n\n\"Consectetur ab neque non sunt autem. =@~&`/sunt\"}, \n \n\n@voluptatibus\n\n\n\n\n\n =    [\n \n\n \n \n\n \n\n\n\n#<@in?       \"Eaque quis accusamus qui.\" \n\n  \n\n\n\n\n\n  =\n\n     \n\n   \n\n \n[\n   \n\n\n\n\n\n  \n\nexercitationem,\n\n\n  \n \n \n\"Voluptatibus nam deserunt exercitationem incidunt molestiae perferendis.\",\n  \n   quasi],\n  \n\n\n   \n\n \n  \"Qui consectetur similique vel perspiciatis quo ea consequatur ut.\"\n\n\n \n\n\n  \n\n\n = \n \n    \n \n\n#<@tenetur     \"Consectetur neque ad eaque voluptas et placeat labore nihil. @`-/=$suscipit\"  \n\n\n\n\n\n\n\n\n=\n\n\n  \n \n\n  \n\n  modi>,  \n \n\"Ipsam voluptates dolor consequuntur eos ab.\" \n\n\n\n  \n=   \n\n  \n \n  \n  \n{\n  \n\n\"Eligendi dolores nobis aut voluptas sunt. =\\\\-*~!?possimus\"\n\n \n\n\n\n\n\n \n=>\n\n\n \n\n    \n  \n   @id?,    \n\n\n\n   \n\n\n\"Rem ea maiores adipisci veniam voluptatem quis. +*)]{dolores\"     \n    =>\n\n\n    \n\n\n\n \n\n2161-01-28T07:55:25-07:00}>]>"
./spec/pretty_formatter_spec.rb:74:in `block (3 levels) in <top (required)>'
-e:1:in `load'
-e:1:in `<main>'
@seed_value = 834097320729099532297468020705382447053

expected: == "Sapiente aliquid odio ratione.\n  #<ipsam\n    \"Ut nobis accusantium at est unde eligendi reprehenderit. #<*$!%(=odit\" =\n      [\n        #<dolor>\n      ],\n    \"Ut minus soluta maxime autem est est. )_[]`{^=*repellendus\" =\n      {\n        \"Fuga quis in nam doloremque facere. +#%{*]<^\\\">quia\" =>\n          #<@quo>,\n        \"A quo placeat alias culpa pariatur. '$>=`[&perspiciatis\" =>\n          {\n            eius: \"Atque dolor natus molestias deserunt.\",\n            aut: 3294.384584741156,\n            \"Magnam dolor non qui beatae.\" => minus?\n          },\n        non: \"Dolore repudiandae illo possimus saepe accusantium impedit necessitatibus. *</?(%_~omnis\"\n      }\n  >\n\n      \n\n  \n\n\n  Vel odio ea eligendi molestias occaecati."
     got:    "Sapiente aliquid odio ratione. \n\n\n\n#<ipsam     \"Ut nobis accusantium at est unde eligendi reprehenderit. #<*$!%(=odit\"      \n  = \n\n\n\n\n \n\n \n\n\n  [ \n\n   \n    \n \n #<dolor   >], \n \n \n\n  \n \"Ut minus soluta maxime autem est est. )_[]`{^=*repellendus\"\n\n \n\n\n\n\n\n\n =\n\n \n\n\n\n\n\n{ \n     \n \"Fuga quis in nam doloremque facere. +#%{*]<^\\\">quia\"\n \n  \n=>  \n\n#<@quo      >,     \n\n    \n \"A quo placeat alias culpa pariatur. '$>=`[&perspiciatis\"      => \n\n\n\n \n{ \n      \n\n  eius:         \"Atque dolor natus molestias deserunt.\",\n \n \n \n\n\n \naut:\n \n3294.384584741156,  \n  \n \"Magnam dolor non qui beatae.\"  \n     \n =>    \n\n \n\n\n\n  \n\n \nminus?},\n\n\n  \n\n\n \n\n  \n\n non:\n\n \n\n\n\n \n\n\n\"Dolore repudiandae illo possimus saepe accusantium impedit necessitatibus. *</?(%_~omnis\"}>\n      \n\n  \n\n\n  Vel odio ea eligendi molestias occaecati."
./spec/pretty_formatter_spec.rb:74:in `block (3 levels) in <top (required)>'
-e:1:in `load'
-e:1:in `<main>'
@seed_value = 818277781571162747200968525300172438290
@seed_value = 678574994695976911851021452633135841032
@seed_value = 275762756281043297189036808180688013498
@seed_value = 769527386187512469458182121371668021367
@seed_value = 728375104595555002312140444458290279219
@seed_value = 750631516563275503288932749072529190613
@seed_value = 298751404833284318753585872939552390014
@seed_value = 823202770923013846487190561274230229143
@seed_value = 651768678698555660920167096020676684937
@seed_value = 283654175046929613135339668092349494076
@seed_value = 176554664590652673204836861360412342639
@seed_value = 345378087599076359605717995462672845800
@seed_value = 595887213256316561765077799954110996279
@seed_value = 780792633442060119723197624349224151569
@seed_value = 306229047869398885951519850937065722925
@seed_value = 224178077159267987119979399182071298515

109 examples, 4 failures, 105 passed

Finished in 2.000001 seconds

Process finished with exit code 1
