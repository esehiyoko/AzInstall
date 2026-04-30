#!/usr/bin/env ruby
require 'sinatra/base'
require 'fileutils'
require 'open3'

FFMPEG_PULL_CMD = [File.expand_path('ffmpeg_pull.rb', __dir__), ''].join(' ')
PID_FILE = File.expand_path('pids.txt', __dir__)

# Sinatraアプリ
class MyApp < Sinatra::Base
  set :bind, '0.0.0.0'
  set :port, 4567

  get '/' do
    'Sinatra is running.'
  end
end

# プロセス管理

def start_ffmpeg_pull
  pid = Process.spawn('ruby', File.expand_path('ffmpeg_pull.rb', __dir__), out: '/dev/null', err: '/dev/null')
  File.open(PID_FILE, 'a') { |f| f.puts pid }
  pid
end

def start_sinatra
  pid = Process.spawn('ruby', File.expand_path($0), '--sinatra', out: '/dev/null', err: '/dev/null')
  File.open(PID_FILE, 'a') { |f| f.puts pid }
  pid
end

def kill_all
  if File.exist?(PID_FILE)
    File.readlines(PID_FILE).each do |line|
      pid = line.strip.to_i
      begin
        Process.kill('TERM', pid)
      rescue Errno::ESRCH
        # already dead
      end
    end
    FileUtils.rm_f(PID_FILE)
  end
end

if ARGV.include?('--kill')
  kill_all
  puts 'All processes killed.'
  exit 0
elsif ARGV.include?('--sinatra')
  MyApp.run!
else
  # 親プロセス
  FileUtils.rm_f(PID_FILE)
  start_ffmpeg_pull
  start_sinatra
  puts 'Started ffmpeg_pull.rb and Sinatra. Use main.rb --kill to stop.'
  Process.waitall
end
