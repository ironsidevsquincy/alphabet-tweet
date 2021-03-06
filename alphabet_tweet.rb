#!/usr/local/bin/ruby

# == Synopsis
#
# alphanbet_tweet: post a word and its definition as a status to twitter account
#
# == Usage
#
# alphabet_tweet [OPTION] --access-secret [secret] --consumer-secret [secret]
#
# -h, --help:
#    show help
#
# --access-secret [secret]
#    access secret
#
# --consumer-secret [secret]
#    consumer secret
#
    
require 'twitter'
require 'dict'
require 'getoptlong'
require 'rdoc'
    
HOSTS = ['www.dict.org']
DB = 'wn'
LETTERS = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z']

# get the command line
opts = GetoptLong.new(
      [ '--help', '-h', GetoptLong::NO_ARGUMENT],
      [ '--access-secret', GetoptLong::REQUIRED_ARGUMENT],
      [ '--consumer-secret', GetoptLong::REQUIRED_ARGUMENT],
      [ '-y', GetoptLong::NO_ARGUMENT]
    )

opts.each do |opt, arg|
      case opt
        when '--help'
          RDoc::usage
        when '--consumer-secret'
          $consumer_secret = arg
        when '--access-secret'
          $access_secret = arg
        when '-y'
          $no_prompt = true
    end
end

if $consumer_secret == nil
  print('Enter the consumer secret: ')
  $consumer_secret = gets.chomp
end
if $access_secret == nil
  print('Enter the access secret: ')
  $access_secret = gets.chomp
end

# create twitter client
client = Twitter::Client.new(:oauth_consumer => {:key =>'10FX27sEXQpUvWNgZsvA', :secret => $consumer_secret}, :oauth_access => {:key => '20802564-BWLtD72Ah4DZpS0fPIIDdiIebvQ7oiYFZPbxofCFy', :secret => $access_secret})

# get the previous post's letter
timeline = client.timeline_for(:me, {:count => 1})
if timeline.empty? or (statusText = timeline[0].text) == ''
  letter = LETTERS[0]
else
  # get first letter of previous status
  firstLetter = statusText[0, 1]
  index = LETTERS.index(firstLetter.downcase)
  if index == LETTERS.length - 1
    letter = LETTERS[0]
  else
    letter = LETTERS[index + 1]
  end
end

# create a new dict object
dict = DICT.new(HOSTS)
dict.client("%s v%s")
match = dict.match(DB, 're', '^' + letter + '\w*$')

while 1 do
  # get a random word
  randomWord = match[DB][rand(match[DB].length)];
  # get it's definition
  define = dict.define(DB, randomWord)
  # filter out 'see other word' style definitions
  if define[0]['definition'][1].index(/see/i) === nil
    definition = define[0]['definition'].join.gsub(/\s+/, ' ').gsub(/\s\[.*?\]/, '')
    definition.capitalize!
    definition.gsub!(/\s(n|v|adj|adv)\s+(\d?):/, ' (\1) \2:')
    # only allow definitions that are less than 140 letters
    if definition.length <= 140
      # post definition to twitter
      puts definition
      if $no_prompt == nil
        puts 'Post defintion to twitter?'
        print('[y/N]: ')
        shouldPost = gets.chomp.downcase
        if shouldPost != 'y' && shouldPost != 'yes'
          puts 'Exiting: Ok, not posting to twitter'
          exit
        end
      end
        puts 'Posting definition...'
        client.status(:post, definition)
      break
    end
  end
  match[DB].delete(randomWord);
  
end