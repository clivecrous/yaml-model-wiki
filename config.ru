require 'rubygems'
require 'wiki'

set :run, false
set :environment, :development
run Sinatra::Application
