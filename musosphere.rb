#!/usr/bin/env ruby
require 'rubygems'
require 'active_record'

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
distanceMultiplier = 30

idToN = {}
nToId = {}

n = 0

artists.each do |artist|
	a = ArtistSphere.new
	a.name = artist.name
	a.id = artist.id
	a.followingIds = artist.followingIds
	a.followedByIds = artist.followedByIds
	a.similarityHash = artist.similarityHash
	if not a.followedByIds.nil?
		a.r = a.followedByIds.length * 2
	else
		a.r = 1
	end

	a.pos = Vec.new((rand(artists.length) - artists.length/2) * distanceMultiplier,
		(rand(artists.length) - artists.length/2) * distanceMultiplier,
		(rand(artists.length) - artists.length/2) * distanceMultiplier)
	a.velocity = Vec.new(0,0,0)

	$spheres[a.id] = a

	nToId[n] = a.id
	idToN[a.id] = n
	n = n.succ
end

$timestep = 1
$kineticEnergy = 0
$deriv = 0
$secondDeriv = 100
$damping = 0.5
$attractionConstant = 2
$repulsionConstant = 0.05

def repulsion(sphere1, sphere2)
	charge = sphere1.r * sphere2.r # more followers == higher repulsion
	r2 = sphere1.pos.distSquared(sphere2.pos)
	return $repulsionConstant * charge / r2
end

def attraction(sphere1, sphere2)
	if sphere1.similarityHash.has_key? sphere2.id
		-1 * $attractionConstant * (sphere1.similarityHash[sphere2.id]/100) * (sphere1.pos.dist(sphere2.pos) - 30)
	else
		0
	end
end

def iterateSystem()
	$kineticEnergy = 0
	$spheres.each do |idA, sA|
		netForce = Vec.new(0, 0, 0)	
		$spheres.each do |idB, sB|
			if idA == idB
				next
			else
				netForce += ((sB.pos - sA.pos) * repulsion(sA, sB))
				if not sA.followingIds.nil?
					if sA.followingIds.include? idB
						netForce += ((sB.pos - sA.pos) * attraction(sA, sB))
					end
				end
			end
		end
		
		sA.velocity = (sA.velocity + (netForce * $timestep)) * $damping
		sA.pos += (sA.velocity * $timestep)
		$kineticEnergy += (sA.r * sA.velocity.magSquared)
	end
end

iterateSystem


until $secondDeriv.abs < 10
	$oldKineticEnergy = $kineticEnergy
	$oldDeriv = $deriv
	iterateSystem
	$deriv = $kineticEnergy - $oldKineticEnergy
	$secondDeriv = $deriv - $oldDeriv
	puts $secondDeriv
	puts $kineticEnergy
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
		
		camera
		@labels.each do |l|
			fill 255, 0, 0
			text l.text, l.x, l.y
		end
	end
end

Spheres.new :title => "Musosphere"
