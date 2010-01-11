#!/usr/bin/ruby

# == Synopsis
#
# alphanbet_tweet: post a word and its definition as a status to twitter
#
# == Usage
#
# alphabet_tweet [OPTION] --user [user] --password [password]
#
# -h, --help:
#    show help
#
# --user [name], -u [name]:
#    twitter user name
#
# --password [password], -p [pasword]:
#    twitter password
#
    
require('rubygems')
gem('twitter4r', '0.3.0')
require('twitter')
require 'dict'
require 'time'
require 'getoptlong'
require 'rdoc/usage'
require 'highline/import'
    
SERVER = 'www.dict.org'
DB = 'wn'
LETTERS = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z']

# get the command line
opts = GetoptLong.new(
      [ '--help', '-h', GetoptLong::NO_ARGUMENT],
      [ '--user', '-u', GetoptLong::REQUIRED_ARGUMENT],
      [ '--password', '-p', GetoptLong::REQUIRED_ARGUMENT],
      [ '-y', GetoptLong::NO_ARGUMENT]
    )

opts.each do |opt, arg|
      case opt
        when '--help'
          RDoc::usage
        when '--user'
          $user = arg
        when '--password'
          $password = arg
        when '-y'
          $no_prompt = true
    end
end

if $user == nil
  print('Enter twitter user name: ')
  $name = gets.chomp
end
if $password == nil
  $password = ask("Enter the password for user '#{$user}':" ) { |q| q.echo = false } 
end

# create twitter client
client = Twitter::Client.new(:login => $user, :password => $password)

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
dict = DICT.new(SERVER)
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

# TODO:
#   1) Search previous posts, make sure it's not a duplicate
#   2) When searching through a letters result, keep track of what random word we've checked - DONE
#   3) Command line arguments; user name/password and whether to confirm status post - DONE
