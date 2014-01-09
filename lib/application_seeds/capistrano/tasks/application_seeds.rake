namespace :deploy do
  desc "Populate the application's database with application_seed data"
  task :application_seeds do
    on roles(:all) do
      if fetch(:rails_env) == 'production'
        raise "You cannot run this task in the production environment"
      end

      within fetch(:latest_release_directory) do
        with rails_env: fetch(:rails_env) do
          if fetch(:dataset) == "" || fetch(:dataset).nil?
            execute :rake, 'db:seed'
          else
            execute :rake, "application_seeds:load\[#{dataset}\]"
          end
        end
      end
    end
  end
end

