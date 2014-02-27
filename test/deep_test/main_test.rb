require File.expand_path(File.dirname(__FILE__) + "/../test_helper")

module DeepTest
  unit_tests do
    test "shutdown calls done_with_work" do
      main = Main.new(nil, stub_everything, nil, central_command = mock)
      central_command.expects(:done_with_work)

      main.shutdown
    end
  end
end
