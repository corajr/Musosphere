#!/usr/bin/env ruby
require 'rubygems'
require 'twitter'
require 'lastfm'
require 'active_record'
require 'launchy'
require 'yaml'

load 'keys.rb'

REQUESTS_LIMIT = 20

args = []
ARGV.each do |a|
  args << ARGV.shift
end


ActiveRecord::Base.establish_connection(
	:adapter => "sqlite3",
	:database => "test"
)

load 'schema.rb'

$lastfm = Lastfm.new(LASTFM_API_KEY, LASTFM_API_SECRET)

begin
	if Token.exists?(:service => "Last.fm")
		token = Token.where(:service => "Last.fm").first.token
		$lastfm.session = $lastfm.auth.get_session(token)['key']
	end
rescue Exception => e
	puts e.message
	token = $lastfm.auth.get_token
	Launchy.open("http://www.last.fm/api/auth/?api_key=#{LASTFM_API_KEY}&token=#{token}")
	puts "After the program has been granted access, please press return: "
	gets
	Token.delete_all(:service => "Last.fm")
	Token.create(:service => "Last.fm", :token => token)
	$lastfm.session = $lastfm.auth.get_session(token)['key']
end

Twitter.configure do |config|
  config.consumer_key = TWITTER_CONSUMER_KEY
  config.consumer_secret = TWITTER_CONSUMER_SECRET
  config.oauth_token = TWITTER_OAUTH_TOKEN
  config.oauth_token_secret = TWITTER_OAUTH_TOKEN_SECRET
end

$twitter = Twitter.new

$requestsMade = 0

def addNewArtist(newArtist)
  newRelatedArtists = $lastfm.artist.get_similar(newArtist).map{|a| a["name"]}.select{|a| not a.nil?}
  users = $twitter.user_search(newArtist, :page => 1, :per_page => 1)
  if not users.nil?
    if not users[0].nil?
      if users[0].verified
        screen_name = users[0].screen_name
        user_id = users[0].id
        following = $twitter.friend_ids(user_id)
        puts newArtist
        puts screen_name
      end
    end
  else
    screen_name = nil
    user_id = nil
    following = nil
  end
  Artist.create(:name => newArtist, :twitterName => screen_name, :relatedArtists => newRelatedArtists, :user_id => user_id, :following => following)
  $requestsMade += 1
end

def searchRelatedArtists(artist)
	relatedArtists = Artist.where(:name => artist).first.relatedArtists
	if relatedArtists.nil?
		puts "#{artist}: none found"
	elsif relatedArtists.respond_to?("each")
		relatedArtists.each do |newArtist|
			if $requestsMade > REQUESTS_LIMIT
				break
			end
			if not Artist.exists?(:name => newArtist)
			  begin
			    addNewArtist(newArtist)
			  rescue
			    p "Adding artist #{newArtist} failed."
			  end
			end
		end
	end
end


  
def rebuildRelationships
	allArtists = Artist.select("*")
	
	ids = {}
	allArtists.each{|a| ids[a.id] = a.user_id}
	
	
	followingIds = {}
	followedByIds = {}
	
	allArtists.each do |a|
		followingIds[a.id] = []
		ids.each do |id, user_id|
			if not a.following.nil?
				if a.following.include? user_id.to_s and user_id != 0 and not user_id.nil?
					followingIds[a.id] << id
					if not followedByIds.has_key?(id)
						followedByIds[id] = []
					end
					followedByIds[id] << a.id
				end
			end
		end
	end

	relations = Hash[Artist.select("id,relatedArtists").map{|a| [a.id, a.relatedArtists]}]
	
	done = []
	pairing = {}
	relations.each do |idA, aRelatedArtists|
		relations.each do |idB, bRelatedArtists|
			if done.include? [idA, idB] or done.include? [idB, idA] or idA == idB
				next
			end
			pairing[[idA, idB]] = (aRelatedArtists & bRelatedArtists).length
		end
	end

	similarityHashes = {}
	
	pairing.each do |pair, result|
		pair.permutation(2).each do |p|
			if not similarityHashes.has_key?(p[0])
				similarityHashes[p[0]] = {}
			end
			similarityHashes[p[0]][p[1]] = result
		end
	end

	allArtists.each do |a|
		a.followingIds = followingIds[a.id]
		a.followedByIds = followedByIds[a.id]
		a.similarityHash = similarityHashes[a.id]
		a.save
	end
end


artists = Artist.select("name").reverse

# if there are arguments on the command-line, try to add them as artists
# artists with a space should be encased in quotes
args.each do |a|
  addNewArtist(a)
end

artists.each do |artist|
	searchRelatedArtists(artist.name)
end
rebuildRelationships

