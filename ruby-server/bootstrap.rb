#!/usr/bin/env ruby
require 'open3'
require 'fileutils'

# チェック項目
errors = []
warnings = []

# Rubyバージョン
ruby_version = RUBY_VERSION
puts "[INFO] Ruby version: #{ruby_version}"
if ruby_version < '2.5'
  errors << "Ruby 2.5以上が必要です (現在: #{ruby_version})"
end

# ffmpeg
ffmpeg_path = `which ffmpeg`.strip
if ffmpeg_path.empty?
  errors << 'ffmpegコマンドが見つかりません'
else
  ffmpeg_ver = `ffmpeg -version 2>&1`.lines.first.strip rescue '不明'
  puts "[INFO] ffmpeg: #{ffmpeg_path} (#{ffmpeg_ver})"
end


# openssl
openssl_path = `which openssl`.strip
if openssl_path.empty?
  errors << 'opensslコマンドが見つかりません（証明書自動生成不可）'
end

# .env
unless File.exist?('.env')
  errors << '.envファイルがありません'
else
  env = File.read('.env')
  %w[BARIX_IP BARIX_MOUNT_POINT].each do |key|
    unless env.match?(/^#{key}=.+/)
      errors << ".envに#{key}が設定されていません"
    end
  end
end

# 必要ディレクトリ
%w[temp sinatra].each do |dir|
  unless Dir.exist?(dir)
    warnings << "ディレクトリがありません: #{dir} (自動作成)"
    FileUtils.mkdir_p(dir)
  end
end

# Gemfile
unless File.exist?('Gemfile')
  warnings << 'Gemfileがありません（Sinatraアプリが動作しない可能性）'
else
  unless system('bundle check > /dev/null 2>&1')
    warnings << 'bundle installが必要です'
  end
end

puts

if errors.any?
  puts "[ERROR] 必須項目の不足・問題:"
  errors.each { |e| puts "  - #{e}" }
  puts "\n[CentOS 7向けインストール例]"
  if errors.any? { |e| e.include?('Ruby') }
    puts "  sudo yum install -y centos-release-scl"
    puts "  sudo yum install -y rh-ruby27 rh-ruby27-ruby-devel"
    puts "  scl enable rh-ruby27 bash  # 以降このシェルで作業"
  end
  if errors.any? { |e| e.include?('ffmpeg') }
    puts "  sudo yum install -y epel-release"
    puts "  sudo yum install -y ffmpeg"
  end
  if errors.any? { |e| e.include?('.env') }
    puts "  cp .env.sample .env  # 例: サンプルからコピーして編集"
  end
  exit 1
end


if warnings.any?
  puts "[WARN] 注意事項:"
  warnings.each { |w| puts "  - #{w}" }
  puts "\n[CentOS 7向け対処例]"
  if warnings.any? { |w| w.include?('Gemfile') }
    puts "  # Gemfileがない場合はリポジトリから取得してください"
  end
  if warnings.any? { |w| w.include?('bundle install') }
    puts "  bundle install"
  end
  if warnings.any? { |w| w.include?('ディレクトリ') }
    puts "  # ディレクトリは自動作成されますが、権限エラー時は手動で mkdir してください"
  end
end


# 自己署名証明書の自動生成
crt = 'server.crt'
key = 'server.key'
if File.exist?(crt) && File.exist?(key)
  puts "[INFO] SSL証明書(server.crt)と秘密鍵(server.key)は既に存在します。上書きしません。"
else
  puts "[INFO] SSL証明書(server.crt)または秘密鍵(server.key)が見つかりません。自己署名証明書を生成します。"
  system("openssl req -x509 -newkey rsa:2048 -nodes -keyout #{key} -out #{crt} -days 365 -subj '/CN=localhost' > /dev/null 2>&1")
  if File.exist?(crt) && File.exist?(key)
    puts "[SUCCESS] 自己署名証明書(server.crt)と秘密鍵(server.key)を生成しました。"
  else
    puts "[ERROR] 証明書の生成に失敗しました。opensslコマンドの有無や権限を確認してください。"
  end
end

# silence.mp3 の生成
duration_sec = 30
env_file = File.expand_path('.env', __dir__)
if File.exist?(env_file)
  File.readlines(env_file).each do |line|
    m = line.match(/^DURATION_SEC=(\d+)/)
    duration_sec = m[1].to_i if m
  end
end
silence_mp3 = File.expand_path('silence.mp3', __dir__)
if File.exist?(silence_mp3)
  puts "[INFO] silence.mp3は既に存在します: #{silence_mp3}"
else
  puts "[INFO] silence.mp3を生成します (#{duration_sec}秒)..."
  ok = system('ffmpeg', '-f', 'lavfi', '-t', duration_sec.to_s, '-i', 'anullsrc=r=44100:cl=stereo',
              '-acodec', 'libmp3lame', '-ar', '44100', '-ac', '2', '-ab', '128k', silence_mp3)
  if ok && File.exist?(silence_mp3)
    puts "[SUCCESS] silence.mp3を生成しました"
  else
    puts "[ERROR] silence.mp3の生成に失敗しました。ffmpegを確認してください"
  end
end

puts "[OK] 環境チェック完了"
