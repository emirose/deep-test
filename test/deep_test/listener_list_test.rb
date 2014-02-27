require File.expand_path(File.dirname(__FILE__) + "/../test_helper")

module DeepTest
  unit_tests do
    test "forwards methods defined in NullListener to all listeners" do
      listener_1, listener_2 = mock, mock
      list = ListenerList.new([listener_1, listener_2])
      listener_1.expects(:starting).with(:agent)
      listener_2.expects(:starting).with(:agent)
      listener_1.expects(:starting_work).with(:agent, :work)
      listener_2.expects(:starting_work).with(:agent, :work)
      list.starting(:agent)
      list.starting_work(:agent, :work)
    end

    test "doesn't forward methods not defined in NullListener" do
      listener = mock
      listener.expects(:to_s).never
      ListenerList.new([listener]).to_s
    end
  end
end
