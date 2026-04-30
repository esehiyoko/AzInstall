#!/usr/bin/env ruby
require 'open3'
require 'fileutils'
require 'time'
require 'dotenv'
Dotenv.load(File.expand_path('.env', __dir__))

# 設定
def build_stream_url
  ip = ENV['BARIX_IP'] || 'barix_ip'
  port = ENV['PORT'] || '80'
  user = ENV['BARIX_USERNAME']
  pass = ENV['BARIX_PASSWORD']
  mount = ENV['BARIX_MOUNT_POINT'] || 'streama.mp3'
  auth = (user && pass && !user.empty? && !pass.empty?) ? "#{user}:#{pass}@" : ''
  "http://#{auth}#{ip}:#{port}/#{mount}"
end

STREAM_URL = build_stream_url
TEMP_DIR = ENV['TEMP_DIR'] || File.expand_path('temp', __dir__)
DURATION_SEC = (ENV['DURATION_SEC'] || 30).to_i
RETRY_WAIT = (ENV['RETRY_WAIT'] || 10).to_i
SILENCE_MP3 = ENV['SILENCE_MP3'] || File.expand_path('silence.mp3', __dir__)
RETENTION_MINUTES = (ENV['RETENTION_MINUTES'] || 60).to_i

FileUtils.mkdir_p(TEMP_DIR)

def copy_silence(out_file)
  if File.exist?(SILENCE_MP3)
    FileUtils.cp(SILENCE_MP3, out_file)
  else
    puts "[#{Time.now}] [FATAL] silence.mp3が見つかりません。bootstrap.rbを先に実行してください: #{SILENCE_MP3}"
  end
end

loop do
  timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
  out_file = File.join(TEMP_DIR, "audio_#{timestamp}.mp3")
  cmd = [
    'ffmpeg',
    '-y',
    '-i', STREAM_URL,
    '-t', DURATION_SEC.to_s,
    '-acodec', 'libmp3lame',
    '-ar', '44100',
    '-ac', '2',
    '-ab', '128k',
    out_file
  ]

  puts "[#{Time.now}] [INFO] ffmpeg start: #{cmd.join(' ')}"
  begin
    stdout_str, stderr_str, status = Open3.capture3(*cmd)
    if status.success? && File.size?(out_file)
      if File.size(out_file) < 1024 * 8
        puts "[#{Time.now}] [WARN] Output too small, overwriting with silence: #{out_file}"
        copy_silence(out_file)
        puts "[#{Time.now}] [INFO] Overwritten with silence: #{out_file}"
      else
        puts "[#{Time.now}] [SUCCESS] Saved: #{out_file}"
      end
    else
      puts "[#{Time.now}] [ERROR] ffmpeg failed, using silence: #{out_file}"
      copy_silence(out_file)
    end
  rescue => e
    puts "[#{Time.now}] [EXCEPTION] #{e.message}"
    copy_silence(out_file)
  end

  # 保存期間を超えた古いファイルを削除
  cutoff = Time.now - RETENTION_MINUTES * 60
  Dir.glob(File.join(TEMP_DIR, 'audio_*.mp3')).each do |f|
    t = File.basename(f)[6..20]
    begin
      frag_time = Time.strptime(t, '%Y%m%d_%H%M%S')
      if frag_time < cutoff
        FileUtils.rm_f(f)
        puts "[#{Time.now}] [INFO] Deleted old fragment: #{f}"
      end
    rescue
      # タイムスタンプが解析できないファイルは無視
    end
  end
end
