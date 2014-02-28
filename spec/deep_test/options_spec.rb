require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

module DeepTest
  describe Options do
    it "should support number_of_agents" do
      Options.new(:number_of_agents => 3).number_of_agents.should == 3
    end

    it "should default to number_of_agents based on cpu info at time of call" do
      options = Options.new({})
      CpuInfo.should_receive(:new).and_return stub("cpu_info", :count => 4)
      options.number_of_agents.should == 4
    end

    it "should have reasonable defaults" do
      options = Options.new({})
      options.pattern.should == nil
      options.metrics_file.should == nil
    end

    it "should support pattern" do
      Options.new(:pattern => '*').pattern.should == '*'
    end

    it "should support distributed_hosts" do
      Options.new(:distributed_hosts => %w[host1 host2]).
        distributed_hosts.should == %w[host1 host2]
    end

    it "should support sync_options" do
      Options.new(:sync_options => {:options => 1}).sync_options.should == {:options => 1}
    end

    it "should support listener" do
      Options.new(:listener => "AListener").
        listener.should == "AListener"
    end

    it "should use DeepTest::NullListener as the default listener" do
      Options.new({}).listener.should == "DeepTest::NullListener"
    end
    
    it "should allow listener to be set with class" do
      class FakeListener; end
      Options.new(:listener => FakeListener).
        listener.should == "DeepTest::FakeListener"
    end

    it "should allow multiple listeners to be specified" do
      class FakeListener1; end
      class FakeListener2; end
      options = Options.new(
        :listener => "DeepTest::FakeListener1,DeepTest::FakeListener2"
      )
      listener = options.new_listener_list
      listener.should be_instance_of(DeepTest::ListenerList)
      listener.listeners.should have(2).listeners
      listener.listeners.first.should be_instance_of(FakeListener1)
      listener.listeners.last.should be_instance_of(FakeListener2)
    end

    it "should create a list of agent listeners upon request" do
      Options.new({}).new_listener_list.should be_instance_of(DeepTest::ListenerList)
    end

    it "should support ui" do
      Options.new(:ui => "AUI").ui.should == "AUI"
    end

    it "should use DeepTest:UIas the default listener" do
      Options.new({}).ui.should == "DeepTest::UI::Console"
    end
    
    it "should allow ui to be set with class" do
      class FakeUI; end
      Options.new(:ui => FakeUI).ui.should == "DeepTest::FakeUI"
    end

    it "should instantiate ui, passing itself as parameter" do
      options = Options.new({})
      DeepTest::UI::Console.should_receive(:new).with(options)
      options.ui_instance
    end

    it "should instantiate ui only one" do
      options = Options.new({})
      options.ui_instance.should equal(options.ui_instance)
    end

    it "should support strings as well as symbols" do
      Options.new("server_port" => 2).server_port.should == 2
    end

    it "should raise error when invalid option is specifed" do
      lambda {
        Options.new(:foo => 1)
      }.should raise_error(Options::InvalidOptionError)
    end

    it "should convert to command line option string" do
      options = Options.new(:number_of_agents => 1)
      options.to_command_line.should == Base64.encode64(Marshal.dump(options)).gsub("\n","")
    end

    it "should parse from command line option string" do
      options = Options.new(:number_of_agents => 2, :pattern => '*')
      parsed_options = Options.from_command_line(options.to_command_line)
      parsed_options.number_of_agents.should == 2
      parsed_options.pattern.should == '*'
    end

    it "should use default option value when no command line option is present" do
      ["", nil].each do |blank_value|
        options = Options.from_command_line(blank_value)
        options.ui == "DeepTest::UI::Console"
      end
    end

    it "should create local deployment by default" do
      options = Options.new({})
      options.new_deployment.should be_instance_of(LocalDeployment) 
    end

    it "should create remote deployment when distributed hosts are specified" do
      options = Options.new(:distributed_hosts => %w[hosts], :sync_options => {:source => "root"})
      Distributed::RemoteDeployment.should_receive(:new).with(options, 
                                                              be_instance_of(Distributed::LandingFleet), 
                                                              be_instance_of(LocalDeployment))
      options.new_deployment
    end

    it "should create a landing fleet with a ship for each host" do
      Socket.should_receive(:gethostname).and_return("myhost")
      options = Options.new(:ui => "DeepTest::UI::Null",
                            :sync_options => {:source => "/my/local/dir"},
                            :distributed_hosts => %w[host1 host2])

      Distributed::RSync.should_receive(:push).with("host1", options.sync_options, "/tmp/myhost_my_local_dir")
      Distributed::RSync.should_receive(:push).with("host2", options.sync_options, "/tmp/myhost_my_local_dir")

      options.new_landing_fleet.push_code(options)
    end


    it "should return localhost as origin_hostname current hostname is same as when created" do
      options = Options.new({})
      options.origin_hostname.should == 'localhost'
    end

    it "should hostname at instantiation when current hostname is different" do
      local_hostname = Socket.gethostname
      options = Options.new({})
      Socket.should_receive(:gethostname).and_return("host_of_query")
      options.origin_hostname.should == local_hostname
    end

    it "should connect_to_central_command on localhost when there is no SSH info" do
      Telegraph::Wire.should_receive(:connect).with("localhost", 9999).and_yield(:wire)
      yielded_wire = nil
      Options.new(:server_port => 9999).connect_to_central_command { |yielded_wire| }
      yielded_wire.should == :wire
    end

    it "should connect_to_central_command on remote address where there is SSH info" do
      Telegraph::Wire.should_receive(:connect).with("remote_address", 9999).and_yield(:wire)
      yielded_wire = nil

      options = Options.new(:server_port => 9999)
      options.ssh_client_connection_info = mock("connection_info", :address => "remote_address")
      options.connect_to_central_command { |yielded_wire| }

      yielded_wire.should == :wire
    end

    it "should be able to calculate mirror_path based on sync_options" do
      Socket.should_receive(:gethostname).and_return("hostname")
      options = Options.new(:sync_options => {:source => "/my/source/path", :remote_base_dir => "/mirror/base/path"})
      options.mirror_path.should == "/mirror/base/path/hostname_my_source_path"
    end

    it "should raise a useful error if no source is specified" do
      options = DeepTest::Options.new(:sync_options => {:remote_base_dir => "/mirror/base/path/"})
      lambda {
        options.mirror_path
      }.should raise_error("No source directory specified in sync_options")
    end

    it "should default to /tmp if no remote_base_dir is specified in sync_options" do
      Socket.should_receive(:gethostname).and_return("hostname")
      options = DeepTest::Options.new(:sync_options => {:source => "/my/source/path"})
      options.mirror_path.should == "/tmp/hostname_my_source_path"
    end

    it "should be gathering metrics if metrics file is set" do
      options = DeepTest::Options.new(:metrics_file => "filename")
      options.should be_gathering_metrics
    end

    it "should not be gathering metrics if metrics file is not set" do
      options = DeepTest::Options.new({})
      options.should_not be_gathering_metrics
    end
  end
end
