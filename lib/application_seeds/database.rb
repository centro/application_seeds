module ApplicationSeeds
  class Database

    class << self
      def connection
        return @connection unless @connection.nil?

        database_config = YAML.load(ERB.new(File.read("config/database.yml")).result)[Rails.env]

        pg_config = {}
        pg_config[:dbname]   = database_config['database']
        pg_config[:host]     = database_config['host']     if database_config['host']
        pg_config[:port]     = database_config['port']     if database_config['port']
        pg_config[:user]     = database_config['username'] if database_config['username']
        pg_config[:password] = database_config['password'] if database_config['password']

        @connection = PG.connect(pg_config)
      end

      def create_metadata_table
        connection.exec('DROP TABLE IF EXISTS application_seeds;')
        connection.exec('CREATE TABLE application_seeds (dataset varchar(255));')
      end
    end

  end
end

if defined?(ActiveRecord)
  ActiveRecord::SchemaDumper.ignore_tables = ["application_seeds"]
end
