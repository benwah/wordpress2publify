wordpress2publify
=================

Wordpress to publify - Loads articles, users, tags and categories (as tags)
from wordpress to publify.

Converts from wordpress to Publish, includes users, posts and tags /
categories (as tags) Somewhat based on  Serendipity (S9Y) 0.8.x converter
for publify by Jochen Schalanda <jochen@schalanda.de>

Warning: Does not convert comments, trackbacks, or anything other than
categories as tags, tags, posts and users.

Author: benoitcsirois(at)gmail.com

MAKE BACKUPS OF EVERYTHING BEFORE RUNNING THIS SCRIPT! THIS SCRIPT IS
PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND

SECURITY NOTICE:

Migrated users will have the default password "password"


Supported version:
==================

Publify: 8.0.1  
Wordpress: Not sure  


How to use
==========

Usage: wordpress.rb [options]

Note: Run this from the root directory of publify install, where the config
directory resides.

Note2: Make sure to include the MySQL database where wordpress data resides
in database.yml, example:

<pre>
dc:  
  adapter: mysql
  host: localhost
  username: myuser
  password: mypass
  database: mydb
  encoding: UTF8
</pre>

Usage example: (Let's say you downloaded this file to ~/Downloads/)

<pre>
$ cd ..plublifylocation..  
$ cp ~/Downloads/wordpress.rb .  
$ ruby wordpress.rb --db-config dc --prefix wp_
</pre>