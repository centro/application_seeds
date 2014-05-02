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

      def without_foreign_keys
        drop_foreign_keys_sql = generate_drop_foreign_keys_sql
        create_foreign_keys_sql = generate_create_foreign_keys_sql

        connection.exec(drop_foreign_keys_sql)
        yield
        connection.exec(create_foreign_keys_sql)
      end

      private

      def generate_drop_foreign_keys_sql
        result = connection.exec <<-SQL
          SELECT 'ALTER TABLE '||nspname||'.'||relname||' DROP CONSTRAINT '||conname||';'
          FROM pg_constraint
          INNER JOIN pg_class ON conrelid=pg_class.oid
          INNER JOIN pg_namespace ON pg_namespace.oid=pg_class.relnamespace
          WHERE contype='f'
          ORDER BY CASE WHEN contype='f' THEN 0 ELSE 1 END,contype,nspname,relname,conname
        SQL
        result.values.join
      end

      def generate_create_foreign_keys_sql
        result = connection.exec <<-SQL
          SELECT 'ALTER TABLE '||nspname||'.'||relname||' ADD CONSTRAINT '||conname||' '|| pg_get_constraintdef(pg_constraint.oid)||';'
          FROM pg_constraint
          INNER JOIN pg_class ON conrelid=pg_class.oid
          INNER JOIN pg_namespace ON pg_namespace.oid=pg_class.relnamespace
          WHERE contype='f'
          ORDER BY CASE WHEN contype='f' THEN 0 ELSE 1 END DESC,contype DESC,nspname DESC,relname DESC,conname DESC;
        SQL
        result.values.join
      end

    end
  end
end
