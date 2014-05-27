require "erb"

module ApplicationSeeds
  class SeedFile
    def self.parse_file(filename)
      YAML.load(ERB.new(File.read(filename)).result)
    end
  end
end
