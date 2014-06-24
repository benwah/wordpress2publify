#!/usr/bin/env ruby

# Converts from wordpress to Publish, includes users, posts and tags / categories (as tags)
# Somewhat based on  Serendipity (S9Y) 0.8.x converter for publify
# by Jochen Schalanda <jochen@schalanda.de>
#
# Warning: Does not convert comments, trackbacks, or anything other than categories as tags,
# tags, posts and users.
#
# Author: benoitcsirois(at)gmail.com
#
# MAKE BACKUPS OF EVERYTHING BEFORE RUNNING THIS SCRIPT!
# THIS SCRIPT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND
#
# SECURITY NOTICE:
#
# Migrated users will have the default password "password"
#

require File.dirname(__FILE__) + '/config/environment'
require 'optparse'


class WPMigrate
  I18n.locale = :en
  attr_accessor :options

  def initialize
    self.options = {}
    self.parse_options
    self.convert_users
    self.convert_articles
  end

  def get_db_name
    ActiveRecord::Base.connection_config[:database]
  end

  def convert_articles
    ActiveRecord::Base.establish_connection(@options[:wp_db])

    wp_entries = ActiveRecord::Base.connection.select_all(%{
      SELECT
      wp.id,
      BIT_OR((CASE comment_status WHEN 'open' THEN TRUE ELSE FALSE END)) AS allow_comments,
      MIN(post_title) as title,
      MIN(post_content) as body,
      MIN(post_excerpt) as excerpt,
      MIN(post_date) AS published_at,
      MIN(post_modified) AS updated_at,
      MIN(post_modified) AS created_at,
      MIN(post_author) as user_id,
      BIT_OR((CASE post_status WHEN 'publish' THEN TRUE ELSE FALSE END)) AS published,
      MIN(wu.user_login) as login,
      GROUP_CONCAT(DISTINCT tags.term_slug SEPARATOR '|') AS tag_slugs,
      GROUP_CONCAT(DISTINCT tags.term_name SEPARATOR '|') AS tag_names
      FROM `#{get_db_name}`.`#{self.options[:wp_prefix]}posts` AS wp
      LEFT OUTER JOIN `#{get_db_name}`.`#{self.options[:wp_prefix]}users` AS wu ON (wu.id = wp.post_author)
      LEFT OUTER JOIN (
          SELECT
              wtr.object_id AS term_post_id,
              wt.name AS term_name,
      	wt.slug AS term_slug
          FROM `#{get_db_name}`.`#{self.options[:wp_prefix]}term_relationships` AS wtr
          LEFT OUTER JOIN `#{get_db_name}`.`#{self.options[:wp_prefix]}term_taxonomy` AS wtt ON ( wtr.term_taxonomy_id = wtt.term_taxonomy_id )
          LEFT OUTER JOIN `#{get_db_name}`.`#{self.options[:wp_prefix]}terms` AS wt ON ( wtt.term_id = wt.term_id )
          WHERE wtt.taxonomy IN ('category', 'post_tag')
      ) AS tags ON (tags.term_post_id = wp.id)
      WHERE wp.post_parent = 0
      GROUP BY wp.id;
    })

    puts "Converting #{wp_entries.size} entries.."

    ActiveRecord::Base.establish_connection

    wp_entries.each do |entry|
      published_at = entry["published_at"]
      modified_at = entry["modified_at"] ? entry["modified_at"] : entry["published_at"]
      puts entry["title"]
      a = Article.new(
                      id: entry["id"],
                      title: entry["title"],
                      body: entry["body"],
                      excerpt: entry["excerpt:"],
                      published_at: published_at,
                      updated_at: modified_at,
                      created_at: modified_at,
                      user_id: entry["user_id"]
                      )
      a.permalink = ActiveSupport::Inflector.transliterate((a.title or '')) # => "aaoouu"
      a.save
      User.where(login: entry["login"]).first.articles << a

      tags = entry["tag_slugs"] ? entry["tag_slugs"].split('|').zip(entry["tag_names"].split('|')) : [] 
      tags.each do |tag|
        c_tag = Tag.find_by_display_name(tag[1].force_encoding('UTF-8')) || Tag.create(:display_name => tag[1].force_encoding('UTF-8'))
        if c_tag.new_record?
          c_tag.updated_at = modified_at
          c_tag.created_at = published_at
        else
          if (
              (modified_at && modified_at != "0000-00-00 00:00:00") &&
              (!c_tag.updated_at || (c_tag.updated_at < DateTime.strptime(modified_at, "%Y-%m-%d %H:%M:%S")))
               )
            c_tag.updated_at = modified_at
          elsif(
                (published_at && published_at != "0000-00-00 00:00:00") &&
                (!c_tag.created_at || (c_tag.created_at > DateTime.strptime(published_at, "%Y-%m-%d %H:%M:%S")))
                )
            c_tag.created_at = published_at
          end
        end
        c_tag.save
        a.tags << c_tag
      end

    end
  end

  def convert_users
    ActiveRecord::Base.establish_connection(@options[:wp_db])

    # binding.pry

    users = ActiveRecord::Base.connection.select_all(%{
      SELECT
        display_name AS name,
        user_login AS login,
        user_email AS email
      FROM `#{get_db_name}`.`#{self.options[:wp_prefix]}users`
    })

    ActiveRecord::Base.establish_connection

    users.each do |user|
      u = User.new
      u.attributes = user
          u.password = "password"
      u.save
    end
  end

  def parse_options
    OptionParser.new do |opt|
      opt.banner = %{"Usage: wordpress.rb [options]"

Note: Run this from the root directory of publify install, where the config
directory resides.

Note2: Make sure to include the MySQL database where wordpress data resides
in database.yml, example:

dc:
  adapter: mysql
  host: localhost
  username: myuser
  password: mypass
  database: mydb
  encoding: UTF8

Usage example: (Let's say you downloaded this file to ~/Downloads/)
cd ..plublifylocation..
cp ~/Downloads/wordpress.rb .
ruby wordpress.rb --db-config dc --prefix wp_

}

      opt.on('--db-config DB', String, 'Wordpress database key in database.yml') { |d| self.options[:wp_db] = d }
      opt.on('--prefix PREFIX', String, 'Wordpress table prefix (defaults to empty string).') { |d| self.options[:wp_prefix] = d }

      opt.on_tail('-h', '--help', 'Show this message.') do
        puts opt
        exit
      end

      opt.parse!(ARGV)
    end

    unless self.options.include?(:wp_db)
      puts "See wordpress.rb --help for help."
      exit
    end

	unless self.options.include?(:wp_prefix)
      self.options[:wp_prefix] = ""
    end
  end
end

WPMigrate.new
