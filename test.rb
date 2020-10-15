require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'ruby-shout'
end

require 'securerandom'
require 'shout'
require './twilio_data'

USE_MP3 = true
ICECAST_PASSWORD = '1234'
AGGREGATE_CHUNKS = true
$big_chunk = '' # global var to store aggregated chunk data

def send_data(s, data)

  if USE_MP3
    audio_data = `echo '#{data}' | base64 --decode | sox -r 8000 -c 1 -e mu-law -t raw - -r 48000 -c 1 -t mp3 -`
  else
    audio_data = `echo '#{data}' | base64 --decode | opusenc --quiet --raw --raw-bits 8 --raw-rate 8000 --raw-chan 1 --bitrate 96 - -`
  end
  m = ShoutMetadata.new
  m.add 'filename', "e#{5}_#{SecureRandom.urlsafe_base64}.mp3"
  m.add 'title', "My episode"
  m.add 'artist', "Mo"
  s.metadata = m
  s.send audio_data
  s.sync

end

def process_data(s, data)
  # send straight to icecast unless we are aggregating
  return send_data(s, data) unless AGGREGATE_CHUNKS

  # aggregate chunks in memory so we make fewer requests
  if $big_chunk && $big_chunk.length > 5000
    send_data(s, $big_chunk)
    $big_chunk = data
  else
    $big_chunk = $big_chunk + data
  end
end

s = Shout.new
s.mount = "stream"
s.charset = "UTF-8"
s.port = 8000
s.host = "64.227.51.69"
s.user = "source"
s.pass = ICECAST_PASSWORD
if USE_MP3
  s.format = Shout::MP3
else
  s.format = Shout::OGG
end
s.description = 'POC Radio'
s.connect


Td.each do |data|
  puts 'Processing data...'
  process_data(s, data)
end
s.disconnect

puts 'Completed'
