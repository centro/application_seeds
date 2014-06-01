module ApplicationSeeds
  class Dataset
    attr_accessor :name, :data_directory
    attr_writer :config, :data_gem_name

    def config
      @config || { :id_type => :integer }
    end

    def data_gem_name
      @data_gem_name ||"application_seed_data"
    end

    def dataset_path
      Dir[File.join(seed_data_path, "**", "*")].detect { |x| File.directory?(x) && File.basename(x) == name }
    end

    def seed_data_path
      return @seed_data_path unless @seed_data_path.nil?

      if data_directory
        @seed_data_path = data_directory
      else
        spec            = Gem::Specification.find_by_name(data_gem_name)
        @seed_data_path = File.join(spec.gem_dir, "lib", "seeds")
      end
      @seed_data_path
    end

    def raw_seed_data
      @raw_seed_data ||= seed_data_files.inject({}) do |raw_seed_data, seed_file|
        raw_seed_data.merge!(seed_file => ApplicationSeeds::SeedFile.parse_file(seed_file))
      end
    end

    def config_values
      @config_values ||= config_files.inject({}) do |config_values, config_file|
        config_values.reverse_merge!(ApplicationSeeds::SeedFile.parse_file(config_file))
      end
    end

    def seed_data_files
      files(pattern: "*.yml") - config_files
    end

    def config_files
      files(pattern: "_config.yml")
    end

    def files(pattern: nil)
      files = []
      path  = dataset_path
      while (seed_data_path != path) do
        files = files + Dir[File.join(path, pattern)]
        path.sub!(/\/[^\/]+$/, "")
      end
      files
    end

    def seed_labels
      return @seed_labels unless @seed_labels.nil?

      @seed_labels = {}
      seed_data_files.each do |seed_file|
        seed_type               = File.basename(seed_file, ".yml")
        @seed_labels[seed_type] ||= {}

        data = raw_seed_data[seed_file]
        if data
          data.each do |label, attributes|
            specified_id                   = attributes['id']
            ids                            = specified_id.nil? ? generate_unique_ids(seed_type, label) : generate_ids(specified_id)
            @seed_labels[seed_type][label] = ids
          end
        end
      end
      @seed_labels
    end

    def processed_seed_data
      return @processed_seed_data unless @processed_seed_data.nil?

      @processed_seed_data = {}
      seed_data_files.each do |seed_file|
        basename = File.basename(seed_file, ".yml")
        data     = raw_seed_data[seed_file]
        if data
          data.each do |label, attributes|
            attributes  = attributes.merge(id: seed_labels[basename][label][id_type(basename)])
            data[label] = replace_labels_with_ids(attributes)
          end

          if processed_seed_data[basename].nil?
            processed_seed_data[basename] = data
          else
            processed_seed_data[basename] = data.merge(processed_seed_data[basename])
          end
        end
      end
      @processed_seed_data
    end

    def replace_labels_with_ids(attributes)
      new_attributes = {}
      attributes.each do |key, value|
        new_attributes[key] = value
        if key =~ /^(.*)_id$/ || key =~ /^(.*)_uuid$/
          new_attributes[key] = replace_single_label($1.pluralize, value)
        end

        if key =~ /^(.*)_ids$/ || key =~ /^(.*)_uuids$/
          new_attributes[key] = replace_array_of_labels($1.pluralize, value)
        end
      end
      new_attributes
    end

    def replace_single_label(type, value)
      # Handle the case where seed data type cannot be determined by the
      # name of the attribute -- employer_id: ma_and_pa (companies)
      if value =~ /\((.*)\)/
        type  = $1
        value = value.sub(/\((.*)\)/, "").strip
      end

      if seed_labels[type]
        label_ids = seed_labels[type][value.to_s]
        value     = label_ids[id_type(type)] if label_ids
      end
      value
    end

    def replace_array_of_labels(type, value)
      # Handle the case where seed data type cannot be determined by the
      # name of the attribute -- employer_ids: [ma_and_pa, super_corp] (companies)
      if value =~ /\((.*)\)/
        type  = $1
        value = value.sub(/\((.*)\)/, "").strip
        value =~ /^\[(.*)\]$/
        value = $1.split(',').map(&:strip)
      end

      if seed_labels[type]
        value = value.map do |v|
          label_ids = seed_labels[type][v.to_s]
          (label_ids && label_ids[id_type(type)]) || v
        end
      end
      value
    end

    def seed_data(type, options)
      type = type.to_s
      raise "No seed data file could be found for '#{type}'" if processed_seed_data[type].nil?

      if options.nil?
        fetch(type)
      elsif options.is_a?(Fixnum) || options.is_a?(String)
        fetch_with_id(type, options)
      elsif options.is_a?(Symbol)
        fetch_with_label(type, options.to_s)
      elsif options.is_a? Hash
        fetch(type) do |attributes|
          options.stringify_keys!
          options = replace_labels_with_ids(options)
          (options.to_a - attributes.to_a).empty?
        end
      end
    end

    def fetch(type, &block)
      result = {}
      processed_seed_data[type].each do |label, attrs|
        attributes = attrs.clone
        id         = seed_labels[type][label][id_type(type)]
        if !block_given? || (block_given? && yield(attributes) == true)
          result[id] = Attributes.new(attributes)
        end
      end
      result
    end

    def fetch_with_id(type, id)
      data = nil
      seed_labels[type].each do |label, ids|
        if ids.values.map(&:to_s).include?(id.to_s)
          data = processed_seed_data[type][label]
          break
        end
      end
      raise "No seed data could be found for '#{type}' with id #{id}" if data.nil?
      Attributes.new(data)
    end

    def fetch_with_label(type, label)
      data = processed_seed_data[type][label]
      raise "No seed data could be found for '#{type}' with label #{label}" if data.nil?
      Attributes.new(data)
    end

    MAX_ID = 2 ** 30 - 1

    def generate_unique_ids(seed_type, label)
      checksum = Zlib.crc32(seed_type + label) % MAX_ID
      generate_ids(checksum)
    end

    def generate_ids(id)
      { :integer => id, :uuid => "00000000-0000-0000-0000-%012d" % id }
    end

    def id_type(type)
      ApplicationSeeds.config["#{type}_id_type".to_sym] || ApplicationSeeds.config[:id_type]
    end

    def clear_cached_data
      @seed_labels         = nil
      @processed_seed_data = nil
      @raw_seed_data       = nil
      @seed_data_files     = nil
      @config_values       = nil
    end
  end
end
