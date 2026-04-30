#!/usr/bin/env ruby
require 'sinatra/base'

require 'time'
require 'json'

class MyApp < Sinatra::Base
  set :bind, '0.0.0.0'
  set :port, 4567

  TEMP_DIR = ENV['TEMP_DIR'] || File.expand_path('../../temp', __dir__)
  DURATION_SEC = (ENV['DURATION_SEC'] || 30).to_i
  DELAY_MIN = (ENV['DELAY_MINUTES'] || ENV['CACHE_KEEP_MINUTES'] || 30).to_i

  helpers do
    def audio_fragments
      Dir.glob(File.join(TEMP_DIR, 'audio_*.mp3')).sort
    end

    def delayed_fragments
      now = Time.now
      delay_sec = DELAY_MIN * 60
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
    latest = files.last
    delay = DELAY_MIN
    status = {
      latest_fragment: latest ? File.basename(latest) : nil,
      fragment_count: files.size,
      delay_minutes: delay,
      temp_dir: TEMP_DIR
    }
    content_type :json
    status.to_json
  end

  get '/live.mp3' do
    content_type 'audio/mpeg'
    files = audio_fragments.last(20) # 直近20個を連結
    stream do |out|
      files.each { |f| File.open(f, 'rb') { |ff| IO.copy_stream(ff, out) } }
    end
  end

  get '/delay.mp3' do
    content_type 'audio/mpeg'
    files = delayed_fragments.last(20) # 遅延分の直近20個を連結
    stream do |out|
      files.each { |f| File.open(f, 'rb') { |ff| IO.copy_stream(ff, out) } }
    end
  end
end

MyApp.run!
