ActiveRecord::Schema.define do
	if not table_exists?(:artists)
		create_table :artists do |table|
			table.column :name, :string
			table.column :twitterName, :string
			table.column :relatedArtists, :string
			table.column :user_id, :integer
			table.column :following, :string
			table.column :followingIds, :string
			table.column :followedByIds, :string
			table.column :similarityHash, :string
		end
	end
	if not table_exists?(:tokens)
		create_table :tokens do |table|
			table.column :service, :string
			table.column :token, :string
		end
	end    
end

class Artist < ActiveRecord::Base
	serialize :relatedArtists
	serialize :followingIds
	serialize :followedByIds
	serialize :similarityHash
end

class Token < ActiveRecord::Base; end