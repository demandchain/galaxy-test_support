module Galaxy
  module TestSupport
    class Configuration
      @@rspec_seed = nil

      def self.rspec_seed=(value)
        @@rspec_seed = value
        srand(value)
      end

      def self.rspec_seed
        @@rspec_seed
      end
    end
  end
end