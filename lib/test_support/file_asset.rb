module TestSupport
  class FileAsset
    class << self
      def asset(asset_name)
        @@asset_list                    ||= {}
        @@asset_list[asset_name.to_sym] = FileAsset.new(asset_name) unless @@asset_list[asset_name.to_sym]
        @@asset_list[asset_name.to_sym]
      end
    end

    def initialize(asset_name)
      @asset_name = asset_name
    end

    def body=(asset_body)
      @asset_body = asset_body
    end

    def add_file(output_location)
      unless (File.exists?(output_location))
        create_file(output_location)
      end
    end

    def create_file(output_location)
      if @asset_body
        File.open(output_location, "a+") do |write_file|
          write_file << @asset_body
        end
      else
        FileUtils.cp File.join(File.dirname(__FILE__), "source_files/#{@asset_body}", @asset_name), output_location
      end
    end
  end
end