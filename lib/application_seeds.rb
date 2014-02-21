require "securerandom"
require "zlib"
require "yaml"
require "erb"
require "pg"
require "active_support"
require "active_support/core_ext"

require "application_seeds/database"
require "application_seeds/version"
require "application_seeds/attributes"

# A library for managing a standardized set of seed data for applications in a non-production environment.
#
# == The API
#
# === Fetching all seeds of a given type
#
#   ApplicationSeeds.campaigns  # where "campaigns" is the name of the seed file
#
# This call returns a hash with one or more entries (depending on the contentes of the seed file).
# The IDs of the object are the keys, and a hash containing the object's attributes are the values.
# An exception is raised if no seed data could be with the given name.
#
# === Fetching seed data by label
#
#   ApplicationSeeds.campaigns(:label)  # where "campaigns" is the name of the seed file, and :label is the label of the campaign
#
# This call returns a hash containing the object's attributes.  An exception is raised if no
# seed data could be found with the given label.
#
# === Fetching seed data by id
#
#   ApplicationSeeds.campaigns(12345)  # where "campaigns" is the name of the seed file, and 12345 is the id of the campaign
#
# This call returns a hash containing the object's attributes.  An exception is raised if no
# seed data could be found with the given id.
#
# === Fetching seed data by some other attribute
#
#   ApplicationSeeds.campaigns(foo: 'bar', name: 'John')  # where "campaigns" is the name of the seed file
#
# This call returns the seed data that contains the specified attributes,
# and the specified attribute values.  It returns a hash with zero or more
# entries.  The IDs of the object are the keys of the hash, and a hash
# containing the object's attributes are the values.  Any empty hash will
# be returned if no seed data could be found with the given attribute names
# and values.
#
# === Creating an object
#
#   ApplicationSeeds.create_object!(Campaign, id, attributes)
#
# This call will create a new instance of the <tt>Campaign</tt> class, with the
# specified id and attributes.
#
# === Rejecting specific attributes
#
#   ApplicationSeeds.create_object!(Campaign, id, attributes.reject_attributes(:unused_attribute))
#
# This call will create a new instance of the <tt>Campaign</tt> class without the
# <tt>unused_attribute</tt> attribute.
#
# === Selecting specific attributes
#
#   ApplicationSeeds.create_object!(Campaign, id, attributes.select_attributes(:attribute1, :attribute2))
#
# This call will create a new instance of the <tt>Campaign</tt> class with only the
# <tt>attribute1</tt> and <tt>attribute2</tt> attributes.
#
# === Mapping attribute names
#
#   ApplicationSeeds.create_object!(Campaign, id, attributes.map_attributes(
#     :old_name1 => :new_name1, :old_name2 => :new_name2))
#
# This call will create a new instance of the <tt>Campaign</tt> class, using the
# seed data for old_name1 as the attribute value for new_name1, and the
# seed data for old_name2 as the attribute value for new_name2.  This
# method let's you easly account for slight differences is attribute names
# across applications.
#
module ApplicationSeeds
  class << self

    #
    # Specify any configuration, such as the type of ids to generate (:integer or :uuid).
    #
    def config=(config)
      warn "WARNING!  Calling ApplicationSeeds.config= after dataset has been set (ApplicationSeeds.dataset=) may not produce expected results." unless @dataset.nil?
      @_config = config
    end

    #
    # Fetch the configuration.
    #
    def config
      @_config ||= { :id_type => :integer }
    end

    #
    # Specify the name of the gem that contains the application seed data.
    #
    def data_gem_name=(gem_name)
      spec = Gem::Specification.find_by_name(gem_name)
      if Dir.exist?(File.join(spec.gem_dir, "lib", "seeds"))
        @data_gem_name = gem_name
      else
        raise "ERROR: The #{gem_name} gem does not appear to contain application seed data"
      end
    end

    #
    # Fetch the name of the directory where the application seed data is loaded from.
    # Defaults to <tt>"applicadtion_seed_data"</tt> if it was not set using <tt>data_gem_name=</tt>.
    #
    def data_gem_name
      @data_gem_name || "application_seed_data"
    end

    #
    # Specify the name of the directory that contains the application seed data.
    #
    def data_directory=(directory)
      if Dir.exist?(directory)
        @data_directory = directory
      else
        raise "ERROR: The #{directory} directory does not appear to contain application seed data"
      end
    end

    #
    # Fetch the name of the directory where the application seed data is loaded from,
    # if it was set using <tt>data_diretory=</tt>.
    #
    def data_directory
      @data_directory
    end

    #
    # Specify the name of the dataset to use.  An exception will be raised if
    # the dataset could not be found.
    #
    def dataset=(dataset)
      clear_cached_data
      @dataset = dataset

      if dataset.nil? || dataset.strip.empty? || dataset_path(dataset).nil?
        datasets = Dir[File.join(seed_data_path, "**", "*")].select { |x| File.directory?(x) }.map { |x| File.basename(x) }.join(', ')

        error_message =  "\nERROR: A valid dataset is required!\n"
        error_message << "Usage: bundle exec rake application_seeds:load[your_data_set]\n\n"
        error_message << "Available datasets: #{datasets}\n\n"
        raise error_message
      end

      store_dataset
    end

    #
    # Returns the name of the dataset that has been loaded, or nil if not
    # running an application_seeds dataset.
    #
    def dataset
      res = Database.connection.exec("SELECT dataset from application_seeds LIMIT 1;")
      res.getvalue(0, 0)
    rescue PG::Error => e
      e.message =~ /relation "application_seeds" does not exist/ ? nil : raise
    end

    #
    # This call will create a new instance of the specified class, with the
    # specified id and attributes.
    #
    def create_object!(clazz, id, attributes, options={})
      validate = options[:validate].nil? ? true : options[:validate]

      x = clazz.new
      x.attributes = attributes.reject { |k,v| !x.respond_to?("#{k}=") }
      x.id = id
      x.save!(:validate => validate)
      x
    end

    #
    # Returns <tt>true</tt> if the specified data file exists in this dataset, <tt>false</tt> if it
    # does not.
    #
    # Examples:
    #   ApplicationSeeds.seed_data_exists?(:campaigns)
    #
    def seed_data_exists?(type)
      !processed_seed_data[type.to_s].nil?
    end

    #
    # This method will reset the sequence numbers on id columns for all tables
    # in the database with an id column.  If you are having issues where you
    # are unable to insert new data into the databse after your dataset has
    # been imported, then this should correct them.
    #
    def reset_sequence_numbers
      result = Database.connection.exec("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';")
      table_names = result.map { |row| row.values_at('table_name')[0] }

      table_names_with_id_column = table_names.select do |table_name|
        result = Database.connection.exec("SELECT column_name FROM information_schema.columns WHERE table_name = '#{table_name}';")
        column_names = result.map { |row| row.values_at('column_name')[0] }
        column_names.include?('id')
      end

      table_names_with_id_column.each do |table_name|
        result = Database.connection.exec("SELECT pg_get_serial_sequence('#{table_name}', 'id');")
        sequence_name = result.getvalue(0, 0)
        Database.connection.exec("SELECT setval('#{sequence_name}', (select MAX(id) from #{table_name}));")
      end
    end

    private

    def dataset_path(dataset)
      Dir[File.join(seed_data_path, "**", "*")].select { |x| File.directory?(x) && File.basename(x) == dataset }.first
    end

    def store_dataset
      Database.create_metadata_table
      Database.connection.exec("INSERT INTO application_seeds (dataset) VALUES ('#{@dataset}');")
    end

    def seed_data_path
      return @seed_data_path unless @seed_data_path.nil?

      if data_directory
        @seed_data_path = data_directory
      else
        spec = Gem::Specification.find_by_name(data_gem_name)
        @seed_data_path = File.join(spec.gem_dir, "lib", "seeds")
      end
      @seed_data_path
    end

    def seed_data_files
      return @seed_data_files unless @seed_data_files.nil?

      @seed_data_files = []
      path = dataset_path(@dataset)
      while (seed_data_path != path) do
        @seed_data_files.concat(Dir[File.join(path, "*.yml")])
        path.sub!(/\/[^\/]+$/, "")
      end
      @seed_data_files
    end

    def raw_seed_data
      return @raw_seed_data unless @raw_seed_data.nil?

      @raw_seed_data = {}
      seed_data_files.each do |seed_file|
        data = YAML.load(ERB.new(File.read(seed_file)).result)
        if data
          @raw_seed_data[seed_file] = data
        end
      end
      @raw_seed_data
    end

    def seed_labels
      return @seed_labels unless @seed_labels.nil?

      @seed_labels = {}
      seed_data_files.each do |seed_file|
        seed_type = File.basename(seed_file, ".yml")
        @seed_labels[seed_type] ||= {}

        data = raw_seed_data[seed_file]
        if data
          data.each do |label, attributes|
            specified_id = attributes['id']
            ids = specified_id.nil? ? generate_unique_ids(seed_type, label) : generate_ids(specified_id)
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
        data = raw_seed_data[seed_file]
        if data
          data.each do |label, attributes|
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
        type = $1
        value = value.sub(/\((.*)\)/, "").strip
      end

      if seed_labels[type]
        label_ids = seed_labels[type][value.to_s]
        value = label_ids[id_type(type)] if label_ids
      end
      value
    end

    def replace_array_of_labels(type, value)
      # Handle the case where seed data type cannot be determined by the
      # name of the attribute -- employer_ids: [ma_and_pa, super_corp] (companies)
      if value =~ /\((.*)\)/
        type = $1
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

    def method_missing(method, *args)
      self.send(:seed_data, method, args.shift)
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
        id = seed_labels[type][label][id_type(type)]
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
          data['id'] = seed_labels[type][label][id_type(type)]
          break
        end
      end
      raise "No seed data could be found for '#{type}' with id #{id}" if data.nil?
      Attributes.new(data)
    end

    def fetch_with_label(type, label)
      data = processed_seed_data[type][label]
      raise "No seed data could be found for '#{type}' with label #{label}" if data.nil?
      data['id'] = seed_labels[type][label][id_type(type)]
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
      self.config["#{type}_id_type".to_sym] || self.config[:id_type]
    end

    def clear_cached_data
      @seed_labels = nil
      @processed_seed_data = nil
      @raw_seed_data = nil
      @seed_data_files = nil
    end
  end
end
