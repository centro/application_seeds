require "securerandom"
require "zlib"
require "yaml"
require "pg"
require "active_support"
require "active_support/core_ext"

require "application_seeds/dataset"
require "application_seeds/database"
require "application_seeds/version"
require "application_seeds/attributes"
require "application_seeds/seed_file"

#
# A library for managing a standardized set of seed data for applications in a non-production environment.
#
# See README.md for API documentation.
#
module ApplicationSeeds
  #
  # See .config and .config=
  #
  DEFAULT_CONFIG        = { :id_type => :integer }
  #
  # See .data_gem_name and .data_gem_name=
  #
  DEFAULT_DATA_GEM_NAME = "application_seed_data"

  class << self
    #
    # Specify any configuration, such as the type of ids to generate (:integer or :uuid).
    #
    def config=(config)
      warn "WARNING!  Calling ApplicationSeeds.config= after dataset has been set (ApplicationSeeds.dataset=) may not produce expected results." unless @dataset.nil?
      the_dataset.config = config
    end

    #
    # Fetch the configuration.
    #
    def config
      the_dataset.config
    end

    #
    # Fetch data from the _config.yml files.
    #
    def config_value(key)
      the_dataset.config_values[key.to_s]
    end

    #
    # Specify the name of the gem that contains the application seed data.
    #
    def data_gem_name=(gem_name)
      spec = Gem::Specification.find_by_name(gem_name)
      if Dir.exist?(File.join(spec.gem_dir, "lib", "seeds"))
        the_dataset.data_gem_name = gem_name
      else
        raise "ERROR: The #{gem_name} gem does not appear to contain application seed data"
      end
    end

    #
    # Fetch the name of the directory where the application seed data is loaded from.
    # Defaults to <tt>"application_seed_data"</tt> if it was not set using <tt>data_gem_name=</tt>.
    #
    def data_gem_name
      the_dataset.data_gem_name
    end

    #
    # Specify the name of the directory that contains the application seed data.
    #
    def data_directory=(directory)
      if Dir.exist?(directory)
        the_dataset.data_directory = directory
      else
        raise "ERROR: The #{directory} directory does not appear to contain application seed data"
      end
    end

    #
    # Fetch the name of the directory where the application seed data is loaded from,
    # if it was set using <tt>data_diretory=</tt>.
    #
    def data_directory
      the_dataset.data_directory
    end

    #
    # Specify the name of the dataset to use.  An exception will be raised if
    # the dataset could not be found.
    #
    def dataset=(dataset_name)
      the_dataset.clear_cached_data
      the_dataset.name = dataset_name

      if dataset_name.nil? || dataset_name.strip.empty? || the_dataset.dataset_path.nil?
        datasets = Dir[File.join(the_dataset.seed_data_path, "**", "*")].select { |x| File.directory?(x) }.map { |x| File.basename(x) }.join(', ')
        error_message =  "\nERROR: A valid dataset is required!\n"
        error_message << "Usage: bundle exec rake application_seeds:load[your_data_set]\n\n"
        error_message << "Available datasets: #{datasets}\n\n"
        raise error_message
      end
    end

    #
    # Returns the name of the current dataset.
    #
    def dataset
      the_dataset.name
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
      !the_dataset.processed_seed_data[type.to_s].nil?
    end

    #
    # This method will reset the sequence numbers on id columns for all tables
    # in the database with an id column.  If you are having issues where you
    # are unable to insert new data into the database after your dataset has
    # been imported, then this should correct them.
    #
    def reset_sequence_numbers
      Database.reset_sequnece_numbers
    end

    #
    # Defer the enforcement of foreign key constraints while the block is being executed.
    #
    def defer_referential_integrity_checks
      Database.without_foreign_keys do
        yield
      end
    end

    #
    # Fetch the label for the associated seed type and ID.
    #
    def label_for_id(seed_type, id)
      x = the_dataset.seed_labels[seed_type.to_s].select { |label, ids| ids[:integer] == id || ids[:uuid] == id }
      x.keys.first.to_sym if x && x.keys.first
    end

    #
    # Resets the configuration.
    #
    def reset!
      @the_dataset = nil
    end

    private

    def the_dataset
      @the_dataset ||= Dataset.new
    end

    def method_missing(method, *args)
      the_dataset.send(:seed_data, method, args.shift)
    end
  end
end
