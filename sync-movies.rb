#!/usr/bin/env ruby

require 'sqlite3'
require 'faraday'
require 'optparse'
options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: ${0} [options]"
  opts.on('-i', '--init', "Initialize or wipe out existing sqlite db") do
    options[:init]=true
  end
end.parse!

#def query_imdbapi title
#  conn = Faraday.new(url:'http://imdbapi.org/')
#  response = conn.get '/', {q:"#{title}", limit:"5"}
#  titles = JSON.parse response.body
#end

class String
  # colorization
  def colorize(color_code); "\e[#{color_code}m#{self}\e[0m"; end
  def red; colorize(31); end
  def green; colorize(32); end
  def yellow; colorize(33); end
  def pink; colorize(35); end
end

module Util
  class << self
    def dialog dialog_params
      tmpfile = Tempfile.new("dialog-response")
      tmpfile.close
      rv = system %Q[dialog #{dialog_params} 2> #{tmpfile.path}]
      tmpfile.open
      choice = tmpfile.read
      tmpfile.unlink
      [rv, choice]
    end
  end
end

class MovieDb
  IgnorePatterns = [ /Gemfile.*/, /sync-movies.rb$/, /movie.db/ ]
  SqlFilename = "movies.db"

  def initialize
    @db = SQLite3::Database.new SqlFilename
  end

  def scan_for_all_files cur_dir
    # get list of all files in cur dir
    allfiles = Dir.glob("#{cur_dir}/*")
    # get list of all dirs in cur dir
    dirs = allfiles.select {|f| File.directory?(f) }
    # return an array of {:filename=>'', :fullpath=>'', :filesize=>''}
    files = allfiles.select {|f| !File.directory?(f) }.
      reject {|f| IgnorePatterns.any?{|pat| f =~ pat} }.
      map    {|f| {:filename=>File.basename(f), :filesize=>File.size(f), :fullpath=>File.realpath(f)} }
    #puts "dirs = #{dirs.inspect}"
    more_files = dirs.map {|dirname| scan_for_all_files(dirname) }
    (files + more_files).flatten.compact
  end

  def normalize_file filename_with_year
    filename_with_year =~ /(.+)(\(\d+\))/
    year = $2
    filename = ($1 && $1.size > 0) ? $1 : filename_with_year
    if year
      year =~ /(\()(\d+)(\))/
      year = $2
    end

    [filename.strip, year]
  end

  def sync_files_to_local_db filelist
    @db.results_as_hash = true
    filelist.select do |file|
      title, year = normalize_file file[:filename]
      stmt = "select * from movies where `title` = '#{title}' "
      stmt << " and `year` = '#{year}'" if year
      puts "DBG stmt = #{stmt}"
      result = @db.execute stmt
      puts "result = #{result.inspect}"
    end
    #new_files
  end

  def self.run
    mdb = MovieDb.new
    files = mdb.scan_for_all_files '.'
    mdb.sync_files_to_local_db files
    puts "files = #{files.inspect}"
  end

  def self.reset_database
    `rm -f '#{SqlFilename}'`
    db = SQLite3::Database.new SqlFilename

    rows = db.execute <<-SQL
    create table if not exists movies (
    id int primary key,
    imdb_id varchar(255),
    title varchar(255),
    description varchar(255),
    year int,
    filesize int,
    genre varchar(255),
    runtime varchar(255),
    poster varchar(255),
    imbdb_url varchar(255),
    orignal_api_response text
    );
    SQL
  end
end

# Moving a file into the system:
#   Pick a file to move
#   Pick a target location
#
# need a local copy of all files in a datastructure. with full path, filesize, filename, year, and metadata
# need a remote copy of the same
# need both to compare

puts "opts = #{options.inspect}"
if options[:init]
  MovieDb.reset_database
end

MovieDb.run



