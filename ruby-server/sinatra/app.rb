#!/usr/bin/env ruby
require 'sinatra/base'

class MyApp < Sinatra::Base
  set :bind, '0.0.0.0'
  set :port, 4567

  get '/' do
    'Sinatra is running.'
  end
end

MyApp.run!
