namespace :deploy do
  desc "Populate the application's database with application_seed data"
  task :application_seeds do
    on roles(:all) do
      if fetch(:rails_env) == 'production'
        raise "You cannot run this task in the production environment"
      end

      within "#{current_path}" do
        with rails_env: fetch(:rails_env) do
          if fetch(:dataset) == "" || fetch(:dataset).nil?
            execute :rake, 'db:seed'
          else
            execute :rake, "application_seeds:load\[#{fetch(:dataset)}\]"
          end
        end
      end
    end
  end
end

