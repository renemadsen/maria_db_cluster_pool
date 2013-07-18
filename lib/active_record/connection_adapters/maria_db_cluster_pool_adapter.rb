module ActiveRecord
  class Base
    class << self
      def maria_db_cluster_pool_connection(config)
        pool_weights = {}

        config = config.with_indifferent_access
        default_config = {:pool_weight => 1}.merge(config.merge(:adapter => config[:pool_adapter])).with_indifferent_access
        default_config.delete(:server_pool)
        default_config.delete(:pool_adapter)

        pool_connections = []
        config[:server_pool].each do |server_config|
          server_config = default_config.merge(server_config).with_indifferent_access
          server_config[:pool_weight] = server_config[:pool_weight].to_i
          begin
            establish_adapter(server_config[:adapter])
            conn = send("#{server_config[:adapter]}_connection".to_sym, server_config)
            conn.class.send(:include, MariaDbClusterPool::ConnectTimeout) unless conn.class.include?(MariaDbClusterPool::ConnectTimeout)
            conn.connect_timeout = server_config[:connect_timeout]
            pool_connections << conn
            pool_weights[conn] = server_config[:pool_weight]
          rescue Exception => e
            if logger
              logger.error("Error connecting to read connection #{server_config.inspect}")
              logger.error(e)
            end
          end
        end if config[:server_pool]

        @maria_db_cluster_pool_classes ||= {}
        klass = @maria_db_cluster_pool_classes[pool_connections[0].class]
        unless klass
          klass = ActiveRecord::ConnectionAdapters::MariaDbClusterPoolAdapter.adapter_class(pool_connections[0])
          @maria_db_cluster_pool_classes[pool_connections[0].class] = klass
        end

        return klass.new(pool_connections[0], logger, pool_connections, pool_weights)
      end

      def establish_adapter(adapter)
        raise AdapterNotSpecified.new("database configuration does not specify adapter") unless adapter
        raise AdapterNotFound.new("database pool must specify adapters") if adapter == 'MariaDB_Cluster_Pool'

        begin
          require 'rubygems'
          gem "activerecord-#{adapter}-adapter"
          require "active_record/connection_adapters/#{adapter}_adapter"
        rescue LoadError
          begin
            require "active_record/connection_adapters/#{adapter}_adapter"
          rescue LoadError
            raise "Please install the #{adapter} adapter: `gem install activerecord-#{adapter}-adapter` (#{$!})"
          end
        end

        adapter_method = "#{adapter}_connection"
        if !respond_to?(adapter_method)
          raise AdapterNotFound, "database configuration specifies nonexistent #{adapter} adapter"
        end
      end
    end
  end

  module ConnectionAdapters
    class MariaDbClusterPoolAdapter < AbstractAdapter
      
      attr_reader :connections # The total sum of connections
      attr_reader :master_connection # The current connection in use
      attr_reader :available_connections # The list of connections usable to the class

      class << self
        # Create an anonymous class that extends this one and proxies methods to the pool connections.
        def adapter_class(master_connection)
          # Define methods to proxy to the appropriate pool
          master_methods = []
          master_connection_classes = [AbstractAdapter, Quoting, DatabaseStatements, SchemaStatements]
          master_connection_classes << DatabaseLimits if const_defined?(:DatabaseLimits)
          master_connection_class = master_connection.class
          while ![Object, AbstractAdapter].include?(master_connection_class) do
            master_connection_classes << master_connection_class
            master_connection_class = master_connection_class.superclass
          end
          master_connection_classes.each do |connection_class|
            master_methods.concat(connection_class.public_instance_methods(false))
            master_methods.concat(connection_class.protected_instance_methods(false))
          end
          master_methods.uniq!
          master_methods -= public_instance_methods(false) + protected_instance_methods(false) + private_instance_methods(false)
          master_methods = master_methods.collect{|m| m.to_sym}

          klass = Class.new(self)
          master_methods.each do |method_name|
            klass.class_eval <<-EOS, __FILE__, __LINE__ + 1
              def #{method_name}(*args, &block)
                return proxy_connection_method(master_connection, :#{method_name}, *args, &block)
              end
            EOS
          end

          return klass
        end
      
        # Set the arel visitor on the connections.
        def visitor_for(pool)
          # This is ugly, but then again, so is the code in ActiveRecord for setting the arel
          # visitor. There is a note in the code indicating the method signatures should be updated.
          config = pool.spec.config.with_indifferent_access
          adapter = config[:master][:adapter] || config[:pool_adapter]
          MariaDbClusterPool.adapter_class_for(adapter).visitor_for(pool)
        end
      end
      
      def initialize(connection, logger, connections, pool_weights)
        super(connection, logger)

        @available_connections = []
        @master_connection = connection
        @connections = connections.dup.freeze

        pool_weights.each_pair do |conn, weight|
          @available_connections[weight] = AvailableConnection.new(conn)
        end
      end
      
      def adapter_name #:nodoc:
        'MariaDB_Cluster_Pool'
      end
      
      # Returns an array of the master connection and the read pool connections
      def all_connections
        @connections
      end

      def requires_reloading?
        false
      end
      
      def visitor=(visitor)
        all_connections.each{|conn| conn.visitor = visitor}
      end
      
      def visitor
        connection.visitor
      end
      
      def active?
        active = true
        do_to_connections {|conn| active &= conn.active?}
        return active
      end

      def reconnect!
        do_to_connections {|conn| conn.reconnect!}
      end

      def disconnect!
        do_to_connections {|conn| conn.disconnect!}
      end

      def reset!
        do_to_connections {|conn| conn.reset!}
      end

      def verify!(*ignored)
        do_to_connections {|conn| conn.verify!(*ignored)}
      end

      def reset_runtime
        total = 0.0
        do_to_connections {|conn| total += conn.reset_runtime}
        total
      end

      class DatabaseConnectionError < StandardError
      end
      
      # This simple class puts an expire time on an array of connections. It is used so the a connection
      # to a down database won't try to reconnect over and over.
      class AvailableConnection
        attr_reader :connection
        attr_writer :failed_connection
        attr_writer :expires
        
        def initialize(connection, failed_connection = false, expires = nil)
          @connection = connection
          @failed_connection = failed_connection
          @expires = expires
        end
        
        def expired?
          @expires ? @expires <= Time.now : false
        end

        def failed?
          @failed_connection
        end

        def reconnect!
          @connection.reconnect!
          if @connection.active?
            @failed_connection = false
            @expires = nil
          else
            raise DatabaseConnectionError.new
          end
        end
      end
      
      # Get the available weighted connections. When a connection is dead and cannot be reconnected, it will
      # be temporarily removed from the read pool so we don't keep trying to reconnect to a database that isn't
      # listening.
      def available_connections
        @available_connections.each do |a|
          if a != nil
            if a.expired?
              begin
              @logger.info("Adding dead database connection back to the pool : #{a.connection.inspect}") if @logger
              a.reconnect!
              rescue  => e
                a.expires = 30.seconds.from_now
                @logger.warn("Failed to reconnect to database when adding connection back to the pool") if @logger
                @logger.warn(e) if @logger
              end
            end
          end
        end

        @available_connections

      end
      
      def reset_available_connections
        @available_connections.each do |a|
          if a != nil
            a.reconnect! rescue nil
          end
        end
      end
      
      # Temporarily remove a connection from the read pool.
      def suppress_connection(conn, expire)
        available = available_connections
        available.each do |a|
          if a != nil
            if a.connection == conn
              a.failed_connection = true
              a.expires = expire.seconds.from_now
              @logger.info("Supressing database connection from the pool : #{a.connection.inspect}") if @logger
            end
          end
        end
      end

      def next_usable_connection
        available = available_connections
        available.each do |a|
          if a != nil
            unless a.failed?
              if a.connection.active?
                @logger.info("New master connection is now : #{a.connection.inspect}") if @logger
                @master_connection = a.connection
                break
              end
            end
          end
        end
      end

      private
      
      def proxy_connection_method(connection, method, *args, &block)
        available_connections
        begin
          connection.send(method, *args, &block)
        rescue ArgumentError
          begin
            connection.send(method, *args)
          rescue ArgumentError
            connection.send(method)
          end
        rescue ActiveRecord::RecordInvalid => e
          throw e
        rescue => e
          # If the statement was a read statement and it wasn't forced against the master connection
          # try to reconnect if the connection is dead and then re-run the statement.
          unless connection.active?
            suppress_connection(@master_connection, 30)
            next_usable_connection
          end
          proxy_connection_method(@master_connection, method, *args, &block)
        end
      end

      # Yield a block to each connection in the pool. If the connection is dead, ignore the error
      def do_to_connections
        all_connections.each do |conn|
          begin
            yield(conn)
          rescue => e
            if @logger
              @logger.warn("Error in do_to_connections")
              @logger.warn(e.message)
              @logger.warn(e.backtrace.inspect)
            end
          end
        end
      end
    end
  end
end
