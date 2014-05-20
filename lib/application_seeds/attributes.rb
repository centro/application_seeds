require 'delegate'

module ApplicationSeeds
  class Attributes < DelegateClass(ActiveSupport::HashWithIndifferentAccess)

    def initialize(attributes)
      super(attributes.with_indifferent_access)
    end

    def select_attributes(*attribute_names)
      attribute_names.map!(&:to_s)
      Attributes.new(select { |k, v| attribute_names.include?(k) })
    end

    def reject_attributes(*attribute_names)
      attribute_names.map!(&:to_s)
      Attributes.new(reject { |k, v| attribute_names.include?(k) })
    end

    def map_attributes(mapping)
      mapping = mapping.with_indifferent_access
      mapped  = inject({}) do |hash, (k, v)|
        mapped_key = mapping.fetch(k) { k }
        hash.merge!(mapped_key => v)
      end
      Attributes.new(mapped)
    end

  end
end
