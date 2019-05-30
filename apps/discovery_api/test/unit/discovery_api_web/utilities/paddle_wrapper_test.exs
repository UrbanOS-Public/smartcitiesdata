defmodule DiscoveryApiWeb.PaddleWrapperTest do
  use ExUnit.Case
  use Placebo
  alias PaddleWrapper

  test "get/1 reconnects to LDAP if Paddle returns an error" do
    allow Paddle.get(filter: any()), return: {:error, :ldap_closed}
    allow Paddle.reconnect(), return: {:ok, :pid}
    PaddleWrapper.get(filter: "blah")

    assert_called Paddle.reconnect(), once()
    assert_called Paddle.get(filter: "blah"), times(2)
  end

  test "get/2 reconnects to LDAP if Paddle returns an error" do
    allow Paddle.get(base: any(), filter: any()), return: {:error, :ldap_closed}
    allow Paddle.reconnect(), return: {:ok, :pid}
    PaddleWrapper.get(base: "yup", filter: "blah")

    assert_called Paddle.reconnect(), once()
    assert_called Paddle.get(base: "yup", filter: "blah"), times(2)
  end

  test "authenticate/2 reconnects to LDAP if Paddle returns an error" do
    allow Paddle.authenticate(any(), any()), return: {:error, {:gen_tcp_error, :enotconn}}
    allow Paddle.reconnect(), return: {:ok, :pid}
    PaddleWrapper.authenticate("user", "pass")

    assert_called Paddle.reconnect(), once()
  end

  test "get/1 returns error if ldap cannot connect" do
    allow Paddle.get(filter: any()), return: {:error, :ldap_closed}
    allow Paddle.reconnect(), return: {:error, :timeout}
    PaddleWrapper.get(filter: "blah")

    assert_called Paddle.reconnect(), once()
    assert_called Paddle.get(filter: "blah"), once()
  end
end
