require 'delegate'

module ApplicationSeeds
  class Attributes < DelegateClass(Hash)

    def initialize(attributes)
      super(attributes)
    end

    def select_attributes(*attribute_names)
      attribute_names.map!(&:to_s)
      Attributes.new(select { |k,v| attribute_names.include?(k) })
    end

    def reject_attributes(*attribute_names)
      attribute_names.map!(&:to_s)
      Attributes.new(reject { |k,v| attribute_names.include?(k) })
    end

    def map_attributes(mapping)
      mapping.stringify_keys!

      mapped = {}
      each do |k,v|
        if mapping.keys.include?(k)
          mapped[mapping[k].to_s] = v
        else
          mapped[k] = v
        end
      end
      Attributes.new(mapped)
    end

  end
end
