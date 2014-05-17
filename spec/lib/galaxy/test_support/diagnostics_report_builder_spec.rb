require 'spec_helper'
require ::File.expand_path("../../../../lib/galaxy/test_support/diagnostics_report_builder", File.dirname(__FILE__))
require "rails"

describe Galaxy::TestSupport::DiagnosticsReportBuilder do
  describe "\#format_code_refs" do
    it "formats a path in a class def" do
      Rails.stub(root: "/path/to/a/folder")

      format_value = Galaxy::TestSupport::DiagnosticsReportBuilder.format_code_refs("#<Proc:0x007fa6fc65b648@#{Rails.root}/spec/controllers/api/v2/partners_controller_spec.rb:15>")
      test_value = "#&lt;Proc:0x007fa6fc65b648@#{Rails.root} <span class=\"test-support-app-file\">/spec/controllers/api/v2/partners_controller_spec.rb:15</span> &gt;"
      expect(format_value).to be == test_value
    end
  end
end