#!/usr/bin/env ruby
require 'open3'
require 'fileutils'
require 'time'

# 設定
STREAM_URL = ENV['STREAM_URL'] || 'http://barix_ip:port/stream'
TEMP_DIR = ENV['TEMP_DIR'] || './temp'
DURATION_SEC = (ENV['DURATION_SEC'] || 60).to_i # 1ファイルあたりの秒数
RETRY_WAIT = (ENV['RETRY_WAIT'] || 10).to_i      # 再接続までの待機秒数
SILENCE_MP3 = ENV['SILENCE_MP3'] || './silence.mp3' # 無音ファイルのパス

FileUtils.mkdir_p(TEMP_DIR)

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

  puts "[#{Time.now}] ffmpeg start: #{cmd.join(' ')}"
  begin
    stdout_str, stderr_str, status = Open3.capture3(*cmd)
    if status.success? && File.size?(out_file)
      puts "[#{Time.now}] Saved: #{out_file}"
    else
      puts "[#{Time.now}] ffmpeg failed, generating silence: #{out_file}"
      # 無音mp3をコピー（なければ生成）
      unless File.exist?(SILENCE_MP3)
        # 1分間の無音mp3を生成
        system('ffmpeg', '-f', 'lavfi', '-t', DURATION_SEC.to_s, '-i', 'anullsrc=r=44100:cl=stereo', '-acodec', 'libmp3lame', '-ar', '44100', '-ac', '2', '-ab', '128k', SILENCE_MP3)
      end
      FileUtils.cp(SILENCE_MP3, out_file)
    end
  rescue => e
    puts "[#{Time.now}] Exception: #{e.message}"
    # 無音mp3をコピー
    unless File.exist?(SILENCE_MP3)
      system('ffmpeg', '-f', 'lavfi', '-t', DURATION_SEC.to_s, '-i', 'anullsrc=r=44100:cl=stereo', '-acodec', 'libmp3lame', '-ar', '44100', '-ac', '2', '-ab', '128k', SILENCE_MP3)
    end
    FileUtils.cp(SILENCE_MP3, out_file)
  end
  sleep 1
end
