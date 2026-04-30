#!/usr/bin/env ruby
require 'fileutils'
require 'open3'
require 'dotenv'
Dotenv.load(File.expand_path('.env', __dir__))

PID_FILE = File.expand_path('pids.txt', __dir__)

# プロセス管理

def start_ffmpeg_pull
  pid = Process.spawn('ruby', File.expand_path('ffmpeg_pull.rb', __dir__), out: '/dev/null', err: '/dev/null')
  File.open(PID_FILE, 'a') { |f| f.puts pid }
  pid
end


def start_sinatra
  sinatra_dir = File.expand_path('sinatra', __dir__)
  config_ru   = File.join(sinatra_dir, 'config.ru')
  port = ENV['LISTEN_PORT'] || '4567'
  crt = File.expand_path('server.crt', __dir__)
  key = File.expand_path('server.key', __dir__)
  bind = if File.exist?(crt) && File.exist?(key)
    "ssl://0.0.0.0:#{port}?cert=#{crt}&key=#{key}"
  else
    "tcp://0.0.0.0:#{port}"
  end
  pid = Process.spawn('bundle', 'exec', 'puma', '-b', bind, config_ru, chdir: sinatra_dir, out: '/dev/null', err: '/dev/null')
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
else
  # 親プロセス
  FileUtils.rm_f(PID_FILE)
  start_ffmpeg_pull
  start_sinatra
  puts 'Started ffmpeg_pull.rb and Sinatra. Use main.rb --kill to stop.'
  Process.waitall
end
