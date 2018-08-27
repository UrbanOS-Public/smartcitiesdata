defmodule CotaStreamingConsumer.HostnameTest do
  use ExUnit.Case

  @hostname "foobar"

  setup_all do
    System.put_env("HOSTNAME", @hostname)
  end

  test "agent gets the correct hostname" do
    hostname = CotaStreamingConsumer.Hostname.get()
    assert hostname = @hostname
  end
end
