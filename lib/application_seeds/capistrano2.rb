module ApplicationSeeds
  module Capistrano

    def self.load_into(configuration)
      configuration.load do
        set :dataset, ""

        namespace :deploy do
          desc "Populate the application's database with application_seed data"
          task :application_seeds do
            raise "You cannot run this task in the production environment" if rails_env == "production"

            if dataset == ""
              run %Q{cd #{latest_release} && #{rake} RAILS_ENV=#{rails_env} db:seed}
            else
              run %Q{cd #{latest_release} && #{rake} RAILS_ENV=#{rails_env} application_seeds:load\[#{dataset}\]}
            end
          end
        end
      end
    end

  end
end

if Capistrano::Configuration.instance
  ApplicationSeeds::Capistrano.load_into(Capistrano::Configuration.instance)
end

