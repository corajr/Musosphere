#!/usr/bin/env ruby
require 'rubygems'
require 'active_record'
require 'matrix'
require 'java' 

module JavaLang                    # create a namespace for java.lang
  include_package "java.lang"      # we don't want to clash with Ruby Thread?
end


ActiveRecord::Base.establish_connection(
	:adapter => "jdbcsqlite3",
	:database => "test"
)

load 'schema.rb'

artists = Artist.select("name, id, followingIds, followedByIds, similarityHash")

class ArtistSphere
	attr_accessor :pos, :r, :name, :id, :followingIds, :followedByIds, :similarityHash, :velocity
end

class Vec
	attr_accessor :x, :y, :z
	def initialize(x, y, z)
		@x = x
		@y = y
		@z = z
	end
	def mag
		Math.sqrt((@x ** 2) + (@y ** 2) + (@z ** 2))
	end	
	def magSquared
		(@x ** 2) + (@y ** 2) + (@z ** 2)
	end
	def +(v)
		Vec.new(@x + v.x, @y + v.y, @z + v.z)
	end
	def -(v)
		Vec.new(@x - v.x, @y - v.y, @z - v.z)
	end
	def *(a)
		Vec.new(@x * a, @y * a, @z * a)
	end
	def dist(v)
		distSq = ((@x - v.x) ** 2) + ((@y - v.y) ** 2) + ((@z - v.z) ** 2)
		if distSq >= 0
			Math.sqrt(distSq)
		else
			0
		end
	end
	def distSquared(v)
		((@x - v.x) ** 2) + ((@y - v.y) ** 2) + ((@z - v.z) ** 2)
	end
end

$spheres = {}

idToN = {}
nToId = {}

n = 0

$coords = Matrix.build(artists.length, 3) { (rand(artists.length) - (artists.length / 2.0)) * 100 }


artists.each do |artist|
	a = ArtistSphere.new
	a.name = artist.name
	a.id = artist.id
	a.followingIds = artist.followingIds
	a.followedByIds = artist.followedByIds
	a.similarityHash = artist.similarityHash
	if not a.followedByIds.nil?
		a.r = a.followedByIds.length * 0.01
	else
		a.r = 0.01
	end

	a.pos = Vec.new($coords[n, 0], $coords[n, 1], $coords[n, 2])
	$spheres[a.id] = a
	idToN[a.id] = n
	nToId[n] = a.id

	n = n.succ
end

load 'smacof.rb'
m = [] # dissimilarity matrix

(0..artists.length - 1).each do |i|
  row = []
  (0..artists.length - 1).each do |j|
    x = $spheres[nToId[i]].similarityHash[nToId[j]]
    if not x.nil?
      row << 100 - x
    else
      row << 0
    end
  end
  m << row
end

$matrix = Matrix[*m]

class ThreadImpl
  include JavaLang::Runnable       # include interface as a 'module'
  
  attr_reader :runner   # instance variables
  
  def initialize
    @runner = JavaLang::Thread.current_thread # get access to main thread
#    puts "...in thread #{JavaLang::Thread.current_thread.get_name}"
  end
  
  def run
    smacof($matrix, $coords, 0.0001)
#    puts "...in thread #{JavaLang::Thread.current_thread.get_name}"
  end
end
  
class Spheres < Processing::App
	load_libraries 'PeasyCam', 'opengl'
	import 'peasy'
	import "processing.opengl" if library_loaded? "opengl"
	attr_reader :cam, :labels
	
	class Label
		attr_accessor :x, :y, :text
		def initialize(x, y, text)
			@x = x
			@y = y
			@text = text
		end
	end

	def setup
	  size 640, 480, OPENGL
	  configure_camera
	  @labels = []
    begin
      thread0 = JavaLang::Thread.new(ThreadImpl.new).start
    rescue 
      puts $!
    end
	end
	
	def configure_camera
	  @cam = PeasyCam.new(self, 100)
	  @cam.set_minimum_distance 50
	  @cam.set_maximum_distance 500
	end
	
	def draw
		background 0
		fill 255
		noStroke
		lights

		@labels.clear
		$spheres.each do |id, s|
			@labels << Label.new(screenX(s.pos.x, s.pos.y, s.pos.z), screenY(s.pos.x, s.pos.y, s.pos.z), s.name)
			if not s.followingIds.nil?
				s.followingIds.each do |nextId|
					stroke 128, 64
					line s.pos.x, s.pos.y, s.pos.z, $spheres[nextId].pos.x, $spheres[nextId].pos.y, $spheres[nextId].pos.z 
				end
			end
			noStroke
			push_matrix
			translate s.pos.x, s.pos.y, s.pos.z
			fill 255
			sphere s.r
			pop_matrix
		end
		
		@cam.beginHUD
		@labels.each do |l|
			fill 255, 0, 0
			text l.text, l.x, l.y
		end
		@cam.endHUD
	end
end

Spheres.new :title => "Musosphere"
