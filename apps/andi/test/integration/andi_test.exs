defmodule AndiTest do
  use ExUnit.Case
  use Divo

  setup do
    Paddle.authenticate([cn: "admin"], "admin")
  end

  test "connects to LDAP" do
    assert {:ok, cn} = Paddle.get(filter: [cn: "admin"])
  end
end
