# dict.rb - a client-side implementation of the DICT protocol (RFC 2229)
#
# $Id: dict.rb,v 1.29 2007/05/20 00:01:36 ianmacd Exp $
# 
# Version : 0.9.4
# Author  : Ian Macdonald <ian@caliban.org>
#
# Copyright (C) 2002-2007 Ian Macdonald
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2, or (at your option)
#   any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software Foundation,
#   Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

=begin

= NAME
Ruby/DICT - client-side DICT protocol library
= SYNOPSIS

  require 'dict'

  dict = DICT.new('dict.org', DICT::DEFAULT_PORT)
  dict.client('a Ruby/DICT client')
  definitions = dict.define(DICT::ALL_DATABASES, 'ruby')

  if definitions
    definitions.each do |d|
      printf("From %s [%s]:\n\n", d.description, d.database)
      d.definition.each { |line| print line }
    end
  end

  dict.disconnect

= DESCRIPTION
Ruby/DICT is a client-side library implementation of the DICT protocol,
as described in ((<RFC 2229|URL:ftp://ftp.isi.edu/in-notes/rfc2229.txt>)).
= CLASS METHODS
--- DICT.new(hosts, port = DICT::DEFAULT_PORT, debug = false, verbose = false)
    This creates a new instance of the DICT class. A DICT object has four
    instance variables: ((|capabilities|)), ((|code|)), ((|message|)) and
    ((|msgid|)). ((|capabilities|)) is an array of Strings relating to
    capabilities implemented on the server, ((|code|)) is the last status
    code returned by the server, ((|message|)) is the text of the message
    related to ((|code|)), and ((|msgid|)) is the message ID returned by the
    server.
= INSTANCE METHODS
--- DICT#disconnect
    Disconnect from the server.
--- DICT#define(database, word)
    Obtain definitions for ((|word|)) from ((|database|)). A list of valid
    databases can be obtained using DICT#show(DICT::DATABASES).

    To show just the first definition found, use ((|DICT::FIRST_DATABASE|))
    as the database name. To show definitions from all databases, use
    ((|DICT::ALL_DATABASES|)).

    On success, this returns an array of Struct:Definition objects.
    ((*nil*)) is returned on failure.
--- DICT#match(database, strategy, word)
    Obtain matches for ((|word|)) from ((|database|)) using ((|strategy|)).

    On success, a hash of arrays is returned. The keys of the hash are the
    database names and the values are arrays of word matches that were found
    in that database. ((*nil*)) is returned on failure.
--- DICT#show_server
    This method retrieves information on the server itself.

    A String is returned on success, while ((*nil*)) is returned on failure.
--- DICT#show_db
    This method retrieves information on the databases offered by the server.

    A Hash indexed on database name and containing database descriptions
    is returned on success, while ((*nil*)) is returned on failure.
--- DICT#show_info(database)
    This method retrieves information on a particular database offered by
    the server.

    A String is returned on success, while ((*nil*)) is returned on failure.
--- DICT#show_strat
    This method retrieves information on the strategies offered by the server.

    A Hash indexed on strategy name and containing strategy descriptions
    is returned on success, while ((*nil*)) is returned on failure.
--- DICT#status
    This method returns a single line String of status information from the
    server.
--- DICT#help
    This method returns a String of help information from the server,
    describing the commands it implements.
--- DICT#client
    This method sends a single line String of information describing a client
    application to the server.
--- DICT#auth(user, secret)
    This method attempts to authenticate ((|user|)) to the server using
    ((|secret|)). Note that ((|secret|)) is not literally passed to the server.
= CONSTANTS
Ruby/DICT uses a lot of constants, mostly for the status codes
returned by DICT servers. See the source for details.

Some of the more interesting other constants:
: DICT::FIRST_DATABASE
  Define or match, stopping at first database where match is found
: DICT::ALL_DATABASES
  Define or match, gathering matches from all databases
: DICT::DEFAULT_MATCH_STRATEGY
  Match using a server-dependent default strategy, which should be the best
  strategy available for interactive spell checking
: DICT::DEFAULT_PORT
  The default port used by DICT servers, namely 2628
: DICT::ERROR
  A Regex constant matching any server status code indicating an error
= EXCEPTIONS
Exception classes are subclasses of the container class DICTError, which is,
itself, a subclass of RuntimeError
--- ConnectError.new(message, code = 2)
    A ConnectError is raised if DICT::new is unable to connect to the chosen
    DICT server for any reason. Program execution will terminate.
--- ProtocolError.new(message, code = 3)
    A ProtocolError exception can be used if a server operation returns a
    status code matching DICT::ERROR. This does not happen automatically. The
    code is stored in the ((|code|)) attribute of the instance of the DICT
    object. Program execution will terminate.
= AUTHOR
Written by Ian Macdonald <ian@caliban.org>
= COPYRIGHT
 Copyright (C) 2002-2007 Ian Macdonald

 This is free software; see the source for copying conditions.
 There is NO warranty; not even for MERCHANTABILITY or FITNESS
 FOR A PARTICULAR PURPOSE.
= SEE ALSO
* ((<"Ruby/DICT home page - http://www.caliban.org/ruby/"|URL:http://www.caliban.org/ruby/>))
* ((<"The DICT development group - http://www.dict.org/"|URL:http://www.dict.org/>))
* ((<"RFC 2229 - ftp://ftp.isi.edu/in-notes/rfc2229.txt"|URL:ftp://ftp.isi.edu/in-notes/rfc2229.txt>))
= BUGS
Send all bug reports, enhancement requests and patches to the
author.
= HISTORY
$Id: dict.rb,v 1.29 2007/05/20 00:01:36 ianmacd Exp $

=end


require 'socket'
require 'digest/md5'


# lines that start with .. need to be reduced to .
#
class String
  def undot!
    sub!(/^\.\./, '.')
  end
end


# a basic exception class for DICT errors
#
class DICTError < RuntimeError
  def initialize(message, code = 1)
    $stderr.puts message
    exit code
  end
end


# deal with connection errors
#
class ConnectError < DICTError
  def initialize(message, code = 2)
    super
  end
end


# deal with status code errors
#
class ProtocolError < DICTError
  def initialize(message, code = 3)
    super
  end
end

# a structure for definitions
#
Definition = Struct.new('Definition', :word, :definition, :database,
			:description)

class DICT
  attr_reader :capabilities, :code, :message, :msgid

  DATABASES_PRESENT		= '110'
  STRATEGIES_AVAILABLE		= '111'
  DATABASE_INFORMATION		= '112'
  HELP_TEXT			= '113'
  SERVER_INFORMATION		= '114'
  CHALLENGE_FOLLOWS		= '130'
  DEFINITIONS_RETRIEVED		= '150'
  WORD_DEFINITION		= '151'
  MATCHES_PRESENT		= '152'
  STATUS_RESPONSE		= '210'
  CONNECTION_ESTABLISHED	= '220'
  CLOSING_CONNECTION		= '221'
  AUTHENTICATION_SUCCESSFUL	= '230'
  OK				= '250'
  SEND_RESPONSE			= '330'
  TEMPORARILY_UNAVAILABLE	= '420'
  SHUTTING_DOWN			= '421'
  UNRECOGNISED_COMMAND		= '500'
  ILLEGAL_PARAMETERS		= '501'
  COMMAND_NOT_IMPLEMENTED	= '502'
  PARAMETER_NOT_IMPLEMENTED	= '503'
  ACCESS_DENIED			= '530'
  AUTH_DENIED			= '531'
  UNKNOWN_MECHANISM		= '532'
  INVALID_DATABASE		= '550'
  INVALID_STRATEGY		= '551'
  NO_MATCH 			= '552'
  NO_DATABASES_PRESENT		= '554'
  NO_STRATEGIES_AVAILABLE	= '555'

  ALL_DATABASES			= '*'
  DEFAULT_MATCH_STRATEGY	= '.'
  DEFAULT_PORT			= 2628
  ERROR				= /^[45]/
  FIRST_DATABASE		= '!'
  MAX_LINE_LENGTH 		= 1024
  PAIR				= /^(\S+)\s"(.+)"\r$/
  REPLY_CODE			= /^\d\d\d/

  def initialize(hosts, port = DEFAULT_PORT, debug = false, verbose = false)
    hosts.each do |host|
      @debug = debug
      @verbose = verbose
      printf("Attempting to connect to %s:%d...\n", host, port) if @verbose

      begin
	@sock = TCPSocket.open(host, port)
      rescue
	next	# cycle through list of servers, if more than one
      end

      break	# continue if connection to this host succeeded
    end

    # catch failure
    raise ConnectError, 'Unable to connect to host' unless defined? @sock

    # check status line on connect
    line = get_line
    raise ConnectError, line if line =~ ERROR

    caps, @msgid = /(?:<(.+?)>\s)?(<.*>)/.match(line)[1..2]
    @capabilities = caps ? caps.split(/\./) : []
    if @verbose
      printf("Capabilities: %s\n", @capabilities.join(', '))
      printf("Msgid: %s\n", @msgid)
    end
  end

  private

  # output a line to the server
  #
  def send_line(command)
    line = command + "\r\n"
    $stderr.printf("SEND: %s", line) if @debug
    @sock.print(line)
  end

  # get a line of input from the server
  #
  def get_line
    line = @sock.readline("\r\n")
    $stderr.printf("RECV: %s", line) if @debug
    line
  end

  # send a command and get a response
  #
  def exec_cmd(command)
    send_line(command)
    line = get_line
    @code, @message = /^(\d\d\d)\s(.*)$/.match(line)[1..2]
    # remember the command just executed
    @command = command
  end

  # determine whether we're at the end of this response
  #
  def end_of_text?(line)
    line =~ /^\.\r$/ ? true : false
  end

  # generic method to issue command and parse response
  #
  def parse_response
    return nil if @code =~ ERROR

    while line = get_line
      # on first pass through loop, create list as either a hash
      # or a string, depending # on what data looks like
      list ||= line =~ PAIR ? Hash.new : ''

      # check for end of data
      return list if line =~ REPLY_CODE

      if ! end_of_text? line
	line.undot!
	(list << line; next) if list.is_a?(String)  # list is just text

	# list is a hash of data pairings
	name, desc = PAIR.match(line)[1..2]
	if @command =~ /^MATCH/
	  list[name] = Array.new unless list[name]
	  list[name] << desc
	else
	  list[name] = desc
	end

      end
    end
  end

  public

  # QUIT from the server
  #
  def disconnect
    exec_cmd('QUIT')
    @sock.close
  end

  # DEFINE a word
  #
  def define(db, word)
    definitions = Array.new
    d = Definition.new
    d.word = word
    d.definition = Array.new

    exec_cmd('DEFINE %s "%s"' % [ db, word ])

    return nil if @code =~ ERROR

    in_text = false
    while line = get_line
      return definitions if line =~ /^#{OK}/

      if ! in_text && line =~ /^#{WORD_DEFINITION}/
	word, d.database, d.description =
	  /^\d\d\d\s"(.+?)"\s(\S+)\s"(.+)"\r$/.match(line)[1..3]
	in_text = true
      elsif end_of_text? line	# finish definition and start a new one
	definitions << d
	d = Definition.new
	d.word = word
	d.definition = Array.new
	in_text = false
      else
	line.undot!
	d.definition << line
      end

    end
  end

  # MATCH a word
  #
  def match(db, strategy, word)
    exec_cmd('MATCH %s %s "%s"' % [ db, strategy, word ])
    parse_response
  end

  # get database list
  #
  def show_db
    exec_cmd("SHOW DB")
    parse_response
  end

  # get strategy list
  #
  def show_strat
    exec_cmd("SHOW STRAT")
    parse_response
  end

  # get information on database
  #
  def show_info(db)
    exec_cmd('SHOW INFO %s' % db)
    parse_response
  end

  # get server information
  #
  def show_server
    exec_cmd("SHOW SERVER")
    parse_response
  end
  
  # request server STATUS information
  #
  def status
    exec_cmd('STATUS')
    @message
  end

  # request server-side HELP
  #
  def help
    exec_cmd('HELP')
    parse_response
  end

  # send CLIENT information
  #
  def client(info)
    exec_cmd('CLIENT %s' % info)
  end

  # AUTHorise user
  #
  def auth(user, secret)
    auth = MD5::new(@msgid + secret).hexdigest
    exec_cmd('AUTH %s %s' % [ user, auth ])
  end

end
