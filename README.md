# Database Cluster [![Build Status](https://travis-ci.org/renemadsen/maria_db_cluster_pool.png)](https://travis-ci.org/renemadsen/maria_db_cluster_pool)

MariaDB Cluster Pool gem is designed for usage with Maria DB Galera Cluster, so this gem will only support a master/master setup

# Configuration

## The pool configuration

The cluster connections are configured in database.yml using the maria_db_cluster_pool adapter. Any properties you configure for the connection will be inherited by all connections in the pool. In this way, you can configure ports, usernames, etc. once instead of for each connection. One exception is that you can set the pool_adapter property which each connection will inherit as the adapter property. Each connection in the pool uses all the same configuration properties as normal for the adapters.

### Example configuration

```ruby
  development:
      adapter: maria_db_cluster_pool
      database: mydb_development
      username: read_user
      password: abc123
      pool_adapter: mysql
      port: 3306
      encoding: utf8
      server_pool:
        - host: read-db-1.example.com
          pool_weight: 1
        - host: read-db-2.example.com
          pool_weight: 2
```

## Rails 2.3.x

To make rake db:migrate, rake db:seed work, remember to put:

```ruby
  config.gem 'maria_db_cluster_pool'
```

in the environment.rb

## Known issues:

```ruby
  rake db:test:clone
```

will not work.

## License

This software is a derived work of https://github.com/bdurand/seamless_database_pool the parts which derives from that codes is copyrighted by Brian Durand

Copyright (C) 2013 Microting A/S

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
