#require 'spec_helper'
#
#describe "MariaDbClusterPool" do
#
#  before(:each) do
#    #MariaDbClusterPool.clear_read_only_connection
#  end
#
#  after(:each) do
#    #MariaDbClusterPool.clear_read_only_connection
#  end
#
#  it "should use the master connection by default" do
#    connection = stub(:connection, :master_connection => :master_db_connection)
#    connection.stub!(:using_master_connection?).and_return(false)
#    MariaDbClusterPool.read_only_connection_type.should == :master
#    MariaDbClusterPool.read_only_connection(connection).should == :master_db_connection
#  end
#
#  it "should be able to set using persistent read connections" do
#    connection = mock(:connection)
#    connection.should_receive(:random_read_connection).once.and_return(:read_db_connection)
#    connection.stub!(:using_master_connection?).and_return(false)
#    MariaDbClusterPool.use_persistent_read_connection
#    MariaDbClusterPool.read_only_connection_type.should == :persistent
#    MariaDbClusterPool.read_only_connection(connection).should == :read_db_connection
#    MariaDbClusterPool.read_only_connection(connection).should == :read_db_connection
#  end
#
#  it "should be able to set using random read connections" do
#    connection = mock(:connection)
#    connection.should_receive(:random_read_connection).and_return(:read_db_connection_1, :read_db_connection_2)
#    connection.stub!(:using_master_connection?).and_return(false)
#    MariaDbClusterPool.use_random_read_connection
#    MariaDbClusterPool.read_only_connection_type.should == :random
#    MariaDbClusterPool.read_only_connection(connection).should == :read_db_connection_1
#    MariaDbClusterPool.read_only_connection(connection).should == :read_db_connection_2
#  end
#
#  it "should use the master connection if the connection is forcing it" do
#    connection = stub(:connection, :master_connection => :master_db_connection)
#    connection.should_receive(:using_master_connection?).and_return(true)
#    MariaDbClusterPool.use_persistent_read_connection
#    MariaDbClusterPool.read_only_connection(connection).should == :master_db_connection
#  end
#
#  it "should be able to set using the master connection" do
#    connection = stub(:connection, :master_connection => :master_db_connection)
#    connection.stub!(:using_master_connection?).and_return(false)
#    MariaDbClusterPool.use_master_connection
#    MariaDbClusterPool.read_only_connection(connection).should == :master_db_connection
#  end
#
#  it "should be able to use persistent read connections within a block" do
#    connection = stub(:connection, :master_connection => :master_db_connection)
#    connection.should_receive(:random_read_connection).once.and_return(:read_db_connection)
#    connection.stub!(:using_master_connection?).and_return(false)
#    MariaDbClusterPool.read_only_connection(connection).should == :master_db_connection
#    MariaDbClusterPool.use_persistent_read_connection do
#      MariaDbClusterPool.read_only_connection(connection).should == :read_db_connection
#      MariaDbClusterPool.read_only_connection(connection).should == :read_db_connection
#      :test_val
#    end.should == :test_val
#    MariaDbClusterPool.read_only_connection(connection).should == :master_db_connection
#  end
#
#  it "should be able to use random read connections within a block" do
#    connection = stub(:connection, :master_connection => :master_db_connection)
#    connection.should_receive(:random_read_connection).and_return(:read_db_connection_1, :read_db_connection_2)
#    connection.stub!(:using_master_connection?).and_return(false)
#    MariaDbClusterPool.read_only_connection(connection).should == :master_db_connection
#    MariaDbClusterPool.use_random_read_connection do
#      MariaDbClusterPool.read_only_connection(connection).should == :read_db_connection_1
#      MariaDbClusterPool.read_only_connection(connection).should == :read_db_connection_2
#        :test_val
#      end.should == :test_val
#    MariaDbClusterPool.read_only_connection(connection).should == :master_db_connection
#  end
#
#  it "should be able to use the master connection within a block" do
#    connection = stub(:connection, :master_connection => :master_db_connection)
#    connection.should_receive(:random_read_connection).once.and_return(:read_db_connection)
#    connection.stub!(:using_master_connection?).and_return(false)
#    MariaDbClusterPool.use_persistent_read_connection
#    MariaDbClusterPool.read_only_connection(connection).should == :read_db_connection
#    MariaDbClusterPool.use_master_connection do
#      MariaDbClusterPool.read_only_connection(connection).should == :master_db_connection
#        :test_val
#      end.should == :test_val
#    MariaDbClusterPool.read_only_connection(connection).should == :read_db_connection
#    MariaDbClusterPool.clear_read_only_connection
#  end
#
#  it "should be able to use connection blocks within connection blocks" do
#    connection = stub(:connection, :master_connection => :master_db_connection)
#    connection.should_receive(:random_read_connection).any_number_of_times.and_return(:read_db_connection)
#    connection.stub!(:using_master_connection?).and_return(false)
#    MariaDbClusterPool.use_persistent_read_connection do
#      MariaDbClusterPool.read_only_connection(connection).should == :read_db_connection
#      MariaDbClusterPool.use_master_connection do
#        MariaDbClusterPool.read_only_connection(connection).should == :master_db_connection
#        MariaDbClusterPool.use_random_read_connection do
#          MariaDbClusterPool.read_only_connection(connection).should == :read_db_connection
#        end
#        MariaDbClusterPool.read_only_connection(connection).should == :master_db_connection
#      end
#    end
#    MariaDbClusterPool.clear_read_only_connection
#  end
#
#  it "should be able to change the persistent connection" do
#    connection = mock(:connection)
#    connection.stub!(:random_read_connection).and_return(:read_db_connection)
#    connection.stub!(:using_master_connection?).and_return(false)
#
#    MariaDbClusterPool.use_persistent_read_connection
#    MariaDbClusterPool.read_only_connection_type.should == :persistent
#    MariaDbClusterPool.read_only_connection(connection).should == :read_db_connection
#    MariaDbClusterPool.set_persistent_read_connection(connection, :another_db_connection)
#    MariaDbClusterPool.read_only_connection(connection).should == :another_db_connection
#
#    MariaDbClusterPool.use_random_read_connection
#    MariaDbClusterPool.read_only_connection_type.should == :random
#    MariaDbClusterPool.read_only_connection(connection).should == :read_db_connection
#    MariaDbClusterPool.set_persistent_read_connection(connection, :another_db_connection)
#    MariaDbClusterPool.read_only_connection(connection).should == :read_db_connection
#  end
#
#  it "should be able to specify a default read connection type instead of :master" do
#    MariaDbClusterPool.read_only_connection_type.should == :master
#    MariaDbClusterPool.read_only_connection_type(nil).should == nil
#  end
#
#end
