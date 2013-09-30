port = ENV["PORT"] || "5000"

# Standardize on postgres
#   Check/assume logged-in user can create databases
#   Use min_warnings
#   config/database.yml.example and perform overwrite
#   Write to readme
#
gem "pg"

gem "unicorn"
gem "foreman"
gem "devise"
gem 'anjlab-bootstrap-rails', :require => 'bootstrap-rails',
                              :github => 'anjlab/bootstrap-rails'

gem_group :development, :test do
  gem 'rspec-rails', '2.13.0'
  gem 'pry'
  gem 'pry-rails'
  gem 'pry-debugger'
  gem 'pry-awesome_print'
  gem 'guard-rspec'
  gem 'guard-bundler'
  gem 'rb-fsevent'
end

gem_group :test do
  gem 'capybara'
  gem 'factory_girl_rails', '4.1.0'
  gem 'forgery'
end

file '.gitignore', <<-GITIGNORE
# See http://help.github.com/ignore-files/ for more about ignoring files.
#
# If you find yourself ignoring temporary files generated by your text editor
# or operating system, you probably want to add a global ignore instead:
#   git config --global core.excludesfile ~/.gitignore_global

# Ignore bundler config
/.bundle

# Ignore the default SQLite database.
/db/*.sqlite3

# Ignore all logfiles and tempfiles.
/log/*.log*
/tmp

config/database.yml
vendor/bundle
GITIGNORE


environment <<-APP_GENERATORS
    config.generators do |g|
      g.orm :active_record
      g.fixture_replacement :factory_girl
    end
APP_GENERATORS

file "spec/support/capybara.rb", <<-CAPYBARA
require 'capybara/rails'
require 'capybara/rspec'

RSpec.configure do |config|
  config.include Capybara::DSL
  #config.include Rails.application.routes.url_helpers
end
CAPYBARA

file "config/unicorn.rb", <<-UNICORN
worker_processes 3
timeout 30
UNICORN

file ".env", <<-DOTENV
PORT=#{port}
RACK_ENV=development
DOTENV

file "Procfile", <<-PROCFILE
web: bundle exec unicorn -p $PORT -c ./config/unicorn.rb
PROCFILE

file "spec/support/focus.rb", <<-FOCUS
RSpec.configure do |config|
  config.filter_run :focused => true
  config.run_all_when_everything_filtered = true
  config.alias_example_to :fit, :focused => true
end
FOCUS

file "spec/support/factory_girl.rb", <<-FACTORY_GIRL
RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods
end
FACTORY_GIRL

app_name = ARGV[0]

file "config/database.yml.example", <<-DATABASE
development:
  adapter: postgresql
  encoding: unicode
  database: #{app_name}_development
  pool: 5

  # Connect on a TCP socket. Omitted by default since the client uses a
  # domain socket that doesn't need configuration. Windows does not have
  # domain sockets, so uncomment these lines.
  #host: localhost
  #port: 5432

  # Schema search path. The server defaults to $user,public
  #schema_search_path: myapp,sharedapp,public

  # Minimum log levels, in increasing order:
  #   debug5, debug4, debug3, debug2, debug1,
  #   log, notice, warning, error, fatal, and panic
  # The server defaults to notice.

# Warning: The database defined as "test" will be erased and
# re-generated from your development database when you run "rake".
# Do not set this db to the same as development or production.
test: &test
  adapter: postgresql
  encoding: unicode
  database: #{app_name}_test
  pool: 5
  min_messages: warning

production:
  adapter: postgresql
  encoding: unicode
  database: #{app_name}_production
  pool: 5
  min_messages: warning
DATABASE

run "bundle install"

generate "rspec:install"
run "bundle exec guard init"
run "rm config/database.yml; cp config/database.yml.example config/database.yml"
rake "db:create:all"

run "rm public/index.html"
generate "devise:install"
generate "devise User"
generate "devise:views"

rake "db:migrate db:test:prepare"

# Handles two suggestions from Devise install process

environment "config.action_mailer.default_url_options = {host: 'localhost:#{port}'}", env: 'development'

route "devise_scope :user do; root to: 'devise/sessions#new'; end"

# Installs twitter bootstrap
#

if yes?("Use Twitter bootstrap?")
  run "mv app/assets/stylesheets/application.css app/assets/stylesheets/application.css.scss"
  run "echo '@import \"twitter/bootstrap\";' > app/assets/stylesheets/application.css.scss"
  run "echo '//= require twitter/bootstrap' > app/assets/javascripts/application.js"
  run "curl https://raw.github.com/bigfleet/rails-templates/master/app.html.erb -o app/views/layouts/application.html.erb"
else
  puts "Please inspect your Gemfile to remove the gem"
  puts "Apapt the app/views/layouts/application.html.erb file to remove Bootstrap-style DOM"
end

git :init
git add: "."
git commit: %Q{ -m 'Initial commit' }

