port = ENV["PORT"] || "5000"
app_name = ARGV[1]

require 'rbconfig'
is_windows = (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)

if is_windows
  gem "thin"
  # https://github.com/ddollar/foreman/issues/348
  gem "foreman", "0.61"
 else
  gem "unicorn"
  gem "foreman"
end

gem "devise"
gem 'bootstrap-sass', '~> 3.3.0'
gem 'autoprefixer-rails'
gem 'font-awesome-sass', '~> 4.1.0'
gem 'bootstrap_form'
gem 'kaminari'
gem 'foreigner'
gem 'rolify'

gem_group :development, :test do
  gem 'rspec-rails'
  gem 'guard-rspec'
  gem 'guard-bundler'
  gem 'rb-fsevent'
end

gem_group :test do
  gem 'capybara'
  gem 'factory_girl_rails', '4.1.0'
  gem 'forgery'
  gem 'launchy'
  gem 'database_cleaner'
  gem "codeclimate-test-reporter", require: nil
end

# Standardize on postgres
#   Check/assume logged-in user can create databases
#   Use min_warnings
#   config/database.yml.example and perform overwrite
#   Write to readme
#
gem "pg"

append_file '.gitignore', <<-GITIGNORE
config/database.yml
vendor/bundle
GITIGNORE


environment <<-APP_GENERATORS
  config.generators do |g|
    g.orm :active_record
    g.test_framework :rspec, 
      :fixtures => true, 
      :view_specs => false, 
      :helper_specs => false, 
      :routing_specs => false, 
      :controller_specs => false, 
      :request_specs => true
    g.fixture_replacement :factory_girl, :dir => "spec/factories"
  end
  config.time_zone = 'Eastern Time (US & Canada)'
APP_GENERATORS

file ".travis.yml", <<-TRAVIS
language: ruby
rvm:
  - "2.1.2"
cache: bundler
before_script:
- cp config/database.travis.yml config/database.yml
- psql -c 'create database #{app_name}_test;' -U postgres
- bundle exec rake db:migrate
after_success:
- curl -o bender https://your-key-location.com/
- chmod 600 bender
- ssh-add bender
- bundle exec cap production deploy
env:
  - CODECLIMATE_REPO_TOKEN=TOKEN
notifications:
  hipchat:
    rooms:
      secure: TOKEN
TRAVIS

file "config/database.travis.yml", <<-TRAVISDB
test:
  adapter: postgresql
  database: #{app_name}_test
  username: postgres
TRAVISDB

file "spec/support/capybara.rb", <<-CAPYBARA
require 'capybara/rails'
require 'capybara/rspec'

RSpec.configure do |config|
  config.include Capybara::DSL
  #config.include Rails.application.routes.url_helpers
end
CAPYBARA

file "spec/support/forgery.rb", <<-FORGERY
FactoryGirl.define do

  sequence :email do |n|
    Forgery(:internet).email_address
  end

  sequence :name do |n|
    Forgery(:name).full_name
  end

  sequence :first_name do |n|
    Forgery(:name).first_name
  end

  sequence :last_name do |n|
    Forgery(:name).last_name
  end
end
FORGERY

file "spec/support/as_user.rb", <<-AS_USER
include Devise::TestHelpers

# gives us the login_as(@user) method when request object is not present
include Warden::Test::Helpers
Warden.test_mode!

# Will run the given code as the user passed in
def as_user(user=nil, &block)
  current_user = user || Factory.create(:user)
  if request.present?
    sign_in(current_user)
  else
    login_as(current_user, :scope => :user)
  end
  block.call if block.present?
  return self
end


def as_visitor(user=nil, &block)
  current_user = user || Factory.stub(:user)
  if request.present?
    sign_out(current_user)
  else
    logout(:user)
  end
  block.call if block.present?
  return self
end
AS_USER

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

file "spec/support/db_cleaner.rb", <<-DB_CLEANER
require 'database_cleaner'
RSpec.configure do |config|

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

end
DB_CLEANER

file ".env", <<-DOTENV
PORT=#{port}
RACK_ENV=development
DOTENV

if is_windows
  file "Procfile", <<-PROCFILE
web: bundle exec thin start -p $PORT
PROCFILE

else
if ENV['BOXEN_SOCKET_DIR']
file "config/unicorn.rb", <<-UNICORN
if ENV['RACK_ENV'] == 'development'
  worker_processes 1
  listen "#{ENV['BOXEN_SOCKET_DIR']}/#{app_name}", :backlog => 1024
  timeout 120
end

after_fork do |server, worker|
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end
UNICORN
else
  file "config/unicorn.rb", <<-UNICORN
worker_processes 3
timeout 30
UNICORN
end
  file "Procfile", <<-PROCFILE
web: bundle exec unicorn -p $PORT -c ./config/unicorn.rb
PROCFILE
end

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

gsub_file 'spec/rails_helper.rb', "# Dir[Rails.root.join", "Dir[Rails.root.join"
run "mkdir spec/features"
run "bundle exec guard init"
if is_windows
else
  run "rm config/database.yml; cp config/database.yml.example config/database.yml"
end
rake "db:create:all"

run "rm public/index.html"
generate "devise:install"
generate "devise User"
generate "devise:views"
generate "rolify Role User"

file "spec/features/login_spec.rb", <<-LOGIN_SPEC
require 'rails_helper'

describe "Logging in", :type => :feature do
  
  let(:user){ create(:user) }

  it "signs me in" do
    visit new_user_session_path
    within("#new_user") do
      fill_in 'Email', :with => user.email
      fill_in 'Password', :with => '12345678'
      click_button 'Log in'
    end
    #save_and_open_page

    expect(page).to have_content 'Signed in successfully.'
  end
end
LOGIN_SPEC

run "rm spec/models/user_spec.rb"
file "spec/models/user_spec.rb", <<-USER_SPEC
require 'rails_helper'

RSpec.describe User, :type => :model do
  context "validation" do
    subject{ build(:user) }
    it{ should be_valid }
  end
end
USER_SPEC

run 'rm spec/factories/users.rb'
file "spec/factories/users.rb", <<-USERS
# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :user do
    email
    password "12345678"
    password_confirmation "12345678"
  end
end
USERS

rake "db:migrate db:test:prepare"

# Handles two suggestions from Devise install process

environment "config.action_mailer.default_url_options = {host: 'localhost:#{port}'}", env: 'development'

generate "controller welcome index"

route "root to: 'welcome#index'"

# Installs twitter bootstrap
#

if yes?("Use Twitter bootstrap?")
  file "app/assets/stylesheets/application.scss", <<-APPSASS
  @import "bootstrap-sprockets";
  @import "bootstrap";
  @import "font-awesome";
APPSASS
  run "rm app/assets/stylesheets/application.css"
  append_file 'app/assets/javascripts/application.js', '//= require bootstrap-sprockets'
  run "curl https://raw.githubusercontent.com/bigfleet/rails-templates/master/app.html.erb -o app/views/layouts/application.html.erb"
  run "curl https://raw.githubusercontent.com/bigfleet/rails-templates/master/front.html.erb -o app/views/welcome/index.html.erb"
else
  puts "Please inspect your Gemfile to remove the gem"
  puts "Adapt the app/views/layouts/application.html.erb file to remove Bootstrap-style DOM"
end

git :init
git add: "."
git commit: %Q{ -m 'Initial commit' }

