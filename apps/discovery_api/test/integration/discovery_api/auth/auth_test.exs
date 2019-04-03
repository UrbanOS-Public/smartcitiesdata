defmodule DiscoveryApi.Auth.AuthTest do
  import ExUnit.CaptureLog
  use ExUnit.Case
  use Divo
  alias SmartCity.Dataset

  setup_all do
    IO.puts("WAIT FOR A LONG TIME")
    Process.sleep(600_000)

    Paddle.authenticate([cn: "admin"], "admin")
    Paddle.add([ou: "People"], objectClass: ["top", "organizationalunit"], ou: "People")
    dn = [uid: "FirstUser", ou: "People"]

    thing = [
      objectClass: ["account", "posixAccount"],
      cn: "FirstUser",
      uid: "FirstUser",
      loginShell: "/bin/bash",
      homeDirectory: "/home/user",
      uidNumber: 501,
      gidNumber: 100,
      userPassword: "{SSHA}/02KaNTR+p0r0KSDfDZfFQiYgyekBsdH"
    ]

    # NOTE: To create the userPassword encrypted hash run:  slappasswd -h {SSHA} -s <password>
    Paddle.add(dn, thing)
  end

  @moduletag capture_log: true
  test "Wait a very long time" do
    IO.puts("WAIT FOR A LONG TIME")
    Process.sleep(120_000)
    assert 200 == 200
  end

  @moduletag capture_log: true
  test "Successfully login via the login url with valid password" do
    %{status_code: status_code, body: body} =
      "http://localhost:4000/api/v1/login"
      |> HTTPoison.get!([], hackney: [basic_auth: {"FirstUser", "admin"}])
      |> Map.from_struct()

    assert "FirstUser logged in." == body
    assert status_code == 200
  end

  @moduletag capture_log: true
  test "Fails attempting to login via the login url with invalid password" do
    %{status_code: status_code, body: body} =
      "http://localhost:4000/api/v1/login"
      |> HTTPoison.get!([], hackney: [basic_auth: {"FirstUser", "badpassword"}])
      |> Map.from_struct()

    assert "Not Authorized" == body
    assert status_code == 401
  end
end
