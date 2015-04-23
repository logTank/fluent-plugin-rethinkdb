# RethinkDB plugin for [Fluentd](http://github.com/fluent/fluentd)

fluent-plugin-logtank-rethinkdb provides output plugin for [Fluentd](http://fluentd.org) ([GitHub](http://github.com/fluent/fluentd))

This plugin is a fork from [ardfard/fluent-plugin-rethink](https://github.com/ardfard/fluent-plugin-rethink), which itself is a fork from [kureikain/fluent-plugin-rethink](https://github.com/kureikain/fluent-plugin-rethink). The original point of this fork is twofold:

1. to log exceptions in order to easier debug and fix connection problems
2. Update to rethinkdb 2

Further features might follow.

# Installation

## Gems

The gem is hosted at [Rubygems.org](http://rubygems.org). You can install the gem as follows:

    $ gem install fluent-plugin-logtank-rethinkdb

# Plugins

## Output plugin

### rethink

Store Fluentd event to RethinkDB database.

#### Configuration

Use _rethink_ type in match.

    <match rethinkdb.**>
      type rethinkdb
      database fluent
      table test

      # Following attibutes are optional
      host localhost
      port 28015

      # Other buffer configurations here
    </match>

##### Auto Tag

It's useful if we want to log message into tables based on its tag. This can be
done with `auto_tag_table`

    <match myapp>
      type rethinkdb
      database fluent
      auto_tag_table true

      # Following attibutes are optional
      host localhost
      port 28015

      # Other buffer configurations here
    </match>

With this configuraiton, all message will be written into `myapp` table.


# Test

Run following command:

    $ bundle exec rake test

# TODO

## More configuration
## Auto create table, db

# Copyright

Copyright:: Copyright (c) 2014- kureikain
License::   Apache License, Version 0.1.0

