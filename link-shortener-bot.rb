# frozen_string_literal: true
require 'telegram/bot'
require 'envyable'
require 'firebase'
require 'uri'
require_relative './services/simple_short_key'

Envyable.load(File.expand_path('env.yml', File.dirname( __FILE__)))

def get_short_url(short_key)
  "http://#{ENV['SHORTENER_HOST']}/#{short_key}"
end

def get_url(text)
  URI.extract(text, ['http', 'https'])[0] || ''
end

def handle_command(message)
  command, param = parse_command(message.text)
  case command
  when /\/start/i
    @bot.api.send_message(chat_id: message.chat.id, text: 'Hey, if you send me a link I can send you a shortened version of it!')
  end
end

def parse_command(text)
  text.split(' ', 2)
end

def is_command?(message)
  message[:entities].each do |val|
    return true if val[:type] == 'bot_command'
  end
  false
end

def handle_message(message)
  # http://stackoverflow.com/questions/1805761/check-if-url-is-valid-ruby
  reply_text = 'are you sure this is a link?';
  unless (long_url = get_url(message.text)).empty?
      base_uri = ENV['FIREBASE_BASE_URI']
      secret_key = ENV['FIREBASE_SECRET_KEY']
      firebase = Firebase::Client.new(base_uri, secret_key)
      short_key = ''
      loop do
        short_key = SimpleShortKey.get_key
        response = firebase.get(short_key)
        break if response.body.nil?
      end
      response = firebase.push(short_key, long_url)
      reply_text = if response.success?
        "#{['alright', 'cool', 'wow', 'ok', 'fine', 'there'].sample}, try #{get_short_url(short_key)}"
      else
        'something is wrong but I donno how to fix it :('
      end
  end
  begin
    @bot.api.send_message(chat_id: message.chat.id, text: reply_text)
  rescue Telegram::Bot::Exceptions::ResponseError
    # do nothing
  end
end

Telegram::Bot::Client.run(ENV['TELEGRAM_BOT_TOKEN']) do |bot|
  @bot = bot
  @bot.listen do |message|
    if is_command?(message)
      handle_command(message)
    else
      handle_message(message)
    end
  end
end

