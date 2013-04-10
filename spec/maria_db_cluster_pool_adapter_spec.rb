require 'spec_helper'

module MariaDbClusterPool
  class MockConnection < ActiveRecord::ConnectionAdapters::AbstractAdapter
    def initialize (name)
      @name = name
    end
    
    def inspect
      "#{@name} connection"
    end
    
    def reconnect!
      sleep(0.1)
    end
  end
  
  #class MockMasterConnection < MockConnection
  #  def insert (sql, name = nil); end
  #  def update (sql, name = nil); end
  #  def execute (sql, name = nil); end
  #  def columns (table_name, name = nil); end
  #end
end

describe "MariaDbClusterPoolAdapter ActiveRecord::Base extension" do
  it "should raise an error if the adapter would be recursive" do
    lambda{ActiveRecord::Base.maria_db_cluster_pool_connection('maria_db_cluster_pool').should_raise(ActiveRecord::AdapterNotFound)}
  end
end

describe "MariaDbClusterPoolAdapter" do
  let(:logger){ ActiveRecord::Base.logger}
  let(:connection_1){ MariaDbClusterPool::MockConnection.new("connection_1") }
  let(:connection_2){ MariaDbClusterPool::MockConnection.new("connection_2") }
  let(:connection_3){ MariaDbClusterPool::MockConnection.new("connection_3") }

  let(:pool_connection) do
    weights = {connection_1 => 1, connection_2 => 2, connection_3 => 3}
    connection_class = ActiveRecord::ConnectionAdapters::MariaDbClusterPoolAdapter.adapter_class(connection_1)
    connection_class.new(connection_1, logger, [connection_1, connection_2, connection_3], weights)
  end

  context "selecting a connection from the pool" do
    it "should initialize the connection pool" do
      pool_connection.master_connection.should == connection_1
      pool_connection.available_connections[0].should == nil
      pool_connection.available_connections[1].connection.should == connection_1
      pool_connection.available_connections[2].connection.should == connection_2
      pool_connection.available_connections[3].connection.should == connection_3
    end
  end

  context "fork to all connections" do
    it "should fork active? to all connections and return true if all are up" do
      connection_1.should_receive(:active?).and_return(true)
      connection_2.should_receive(:active?).and_return(true)
      connection_3.should_receive(:active?).and_return(true)
      pool_connection.active?.should == true
    end

    it "should fork active? to all connections and return false if one is down" do
      connection_1.should_receive(:active?).and_return(true)
      connection_2.should_receive(:active?).and_return(true)
      connection_3.should_receive(:active?).and_return(false)
      pool_connection.active?.should == false
    end

    it "should fork verify! to all connections" do
      connection_1.should_receive(:verify!).with(5)
      connection_2.should_receive(:verify!).with(5)
      connection_3.should_receive(:verify!).with(5)
      pool_connection.verify!(5)
    end

    it "should fork disconnect! to all connections" do
      connection_1.should_receive(:disconnect!)
      connection_2.should_receive(:disconnect!)
      connection_3.should_receive(:disconnect!)
      pool_connection.disconnect!
    end

    it "should fork reconnect! to all connections" do
      connection_1.should_receive(:reconnect!)
      connection_2.should_receive(:reconnect!)
      connection_3.should_receive(:reconnect!)
      pool_connection.reconnect!
    end

    it "should fork reset_runtime to all connections" do
      connection_1.should_receive(:reset_runtime).and_return(1)
      connection_2.should_receive(:reset_runtime).and_return(2)
      connection_3.should_receive(:reset_runtime).and_return(3)
      pool_connection.reset_runtime.should == 6
    end
  end

  context "reconnection" do
    it "should proxy requests to a connection" do
      args = [:arg1, :arg2]
      block = Proc.new{}
      connection_1.should_receive(:select_value).with(*args, &block)
      connection_1.should_not_receive(:active?)
      connection_1.should_not_receive(:reconnect!)
      pool_connection.send(:proxy_connection_method, connection_1, :select_value, *args, &block)
    end

    it "should return dead connections to the pool after the timeout has expired" do
      pool_connection.available_connections[1].connection.should == connection_1
      pool_connection.available_connections[1].failed?.should == false
      pool_connection.suppress_connection(connection_1, 0.2)
      pool_connection.available_connections[1].failed?.should == true
      sleep(0.3)
      pool_connection.available_connections[1].connection.should == connection_1
      pool_connection.available_connections[1].failed?.should == false
    end

    it "should not return a connection to the pool until it can be reconnected" do
      pool_connection.available_connections[1].connection.should == connection_1
      pool_connection.available_connections[1].failed?.should == false
      pool_connection.suppress_connection(connection_1, 0.2)
      pool_connection.available_connections[1].failed?.should == true
      sleep(0.3)
      connection_1.should_receive(:reconnect!)
      connection_1.should_receive(:active?).and_return(false)
      pool_connection.available_connections[1].failed?.should == true
    end

    it "should try all connections again if none of them can be reconnected" do
      stack = pool_connection.instance_variable_get(:@available_connections)

      available = pool_connection.available_connections
      available[1].connection.should == connection_1
      available[1].failed?.should == false
      available[2].connection.should == connection_2
      available[2].failed?.should == false
      available[3].connection.should == connection_3
      available[3].failed?.should == false
      stack.size.should == 4

      pool_connection.suppress_connection(connection_1, 30)
      available = pool_connection.available_connections
      available[1].connection.should == connection_1
      available[1].failed?.should == true
      available[2].connection.should == connection_2
      available[2].failed?.should == false
      available[3].connection.should == connection_3
      available[3].failed?.should == false
      stack.size.should == 4

      pool_connection.suppress_connection(connection_2, 30)
      available[1].connection.should == connection_1
      available[1].failed?.should == true
      available[2].connection.should == connection_2
      available[2].failed?.should == true
      available[3].connection.should == connection_3
      available[3].failed?.should == false
      stack.size.should == 4

      pool_connection.suppress_connection(connection_3, 30)
      available[1].connection.should == connection_1
      available[1].failed?.should == true
      available[2].connection.should == connection_2
      available[2].failed?.should == true
      available[3].connection.should == connection_3
      available[3].failed?.should == true
      stack.size.should == 4
    end
  end
end
