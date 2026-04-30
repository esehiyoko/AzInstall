#!/usr/bin/env ruby
require 'sinatra/base'

require 'time'
require 'json'

class MyApp < Sinatra::Base
  set :bind, '0.0.0.0'
  set :port, 4567

  TEMP_DIR = ENV['TEMP_DIR'] || File.expand_path('../../temp', __dir__)
  DURATION_SEC = (ENV['DURATION_SEC'] || 30).to_i
  DELAY_MINUTES = (ENV['DELAY_MINUTES'] || 30).to_i

  helpers do
    def audio_fragments
      Dir.glob(File.join(TEMP_DIR, 'audio_*.mp3')).sort
    end

    def delayed_fragments
      now = Time.now
      delay_sec = DELAY_MINUTES * 60
      audio_fragments.select do |f|
        t = File.basename(f)[6..20] # 'audio_YYYYmmdd_HHMMSS.mp3'
        begin
          frag_time = Time.strptime(t, '%Y%m%d_%H%M%S')
          frag_time <= now - delay_sec
        rescue
          false
        end
      end
    end
  end


  get ['/','/index.html'] do
    files = audio_fragments
    @latest_fragment = files.last ? File.basename(files.last) : nil
    @fragment_count = files.size
    @delay_minutes = DELAY_MINUTES
    @temp_dir = TEMP_DIR
    erb :index
  end

  get '/live.mp3' do
    content_type 'audio/mpeg'
    stream do |out|
      last_sent = nil
      loop do
        files = audio_fragments
        files = files.drop_while { |f| f != last_sent } if last_sent
        files.shift if last_sent # skip the last sent file itself
        files.each do |f|
          File.open(f, 'rb') { |ff| IO.copy_stream(ff, out) }
          last_sent = f
        end
        sleep 1
      end
    end
  end

  get '/delay.mp3' do
    content_type 'audio/mpeg'
    stream do |out|
      last_sent = nil
      loop do
        files = delayed_fragments
        files = files.drop_while { |f| f != last_sent } if last_sent
        files.shift if last_sent
        files.each do |f|
          File.open(f, 'rb') { |ff| IO.copy_stream(ff, out) }
          last_sent = f
        end
        sleep 1
      end
    end
  end
end

MyApp.run!
