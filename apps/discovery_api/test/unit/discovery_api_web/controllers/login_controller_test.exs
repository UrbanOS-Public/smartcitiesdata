defmodule DiscoveryApiWeb.LoginControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo

  alias Plug.Conn
  alias DiscoveryApi.Schemas.Users

  @username "bob"
  @email "a@b.com"

  describe "GET /login" do
    setup do
      allow(PaddleWrapper.authenticate(@username, "12345"), return: :ok)
      allow(PaddleWrapper.authenticate(nil, nil), return: {:error, :invalidCredentials})
      allow(PaddleWrapper.get(filter: [uid: @username]), return: {:ok, [Helper.ldap_user(%{"mail" => [@email]})]})
      allow(Users.create_or_update(any(), any()), return: {:ok, %{}})

      conn =
        build_conn()
        |> Conn.put_req_header("authorization", "Basic " <> Base.encode64("#{@username}:12345"))
        |> get("/api/v1/login")

      conn |> response(200)

      {:ok, %{response_conn: conn}}
    end

    test "returns cookie with httponly", %{response_conn: conn} do
      cookie = conn |> Helper.extract_response_cookie_as_map()

      assert Map.get(cookie, "HttpOnly") == true
    end

    test "returns cookie with secure", %{response_conn: conn} do
      cookie = conn |> Helper.extract_response_cookie_as_map()

      assert Map.get(cookie, "secure") == true
    end

    test "returns cookie token with type 'refresh'", %{response_conn: conn} do
      cookie = conn |> Helper.extract_response_cookie_as_map()

      {:ok, token} =
        cookie
        |> Map.get(Helper.default_guardian_token_key())
        |> DiscoveryApi.Auth.Guardian.decode_and_verify()

      assert Map.get(token, "typ") == "refresh"
    end

    test "returns token header with type 'access'", %{response_conn: conn} do
      {:ok, token} =
        conn
        |> Conn.get_resp_header("token")
        |> List.first()
        |> DiscoveryApi.Auth.Guardian.decode_and_verify()

      assert Map.get(token, "typ") == "access"
    end

    test "saves user with username as subject_id and email from LDAP" do
      assert_called Users.create_or_update(@username, %{email: @email})
    end
  end

  describe "GET /login fails" do
    setup %{conn: conn} do
      allow(PaddleWrapper.authenticate(any(), any()), return: {:error, :invalidCredentials})
      allow(Users.create_or_update(any(), any()), return: {:ok, %{}})

      conn
      |> Conn.put_req_header("authorization", "Basic " <> Base.encode64("#{@username}:12345"))
      |> get("/api/v1/login")
      |> response(401)

      :ok
    end

    test "does not save user" do
      refute_called Users.create_or_update(any(), any())
    end
  end

  @moduletag capture_log: true
  test "GET /login saves user with no email address" do
    allow(PaddleWrapper.authenticate(@username, "12345"), return: :ok)
    allow(PaddleWrapper.get(filter: [uid: @username]), return: {:ok, [Helper.ldap_user()]})
    allow(Users.create_or_update(any(), any()), return: {:ok, %{}})

    build_conn()
    |> Conn.put_req_header("authorization", "Basic " <> Base.encode64("#{@username}:12345"))
    |> get("/api/v1/login")
    |> response(200)

    assert_called Users.create_or_update(@username, %{email: "N/A"})
  end

  describe "GET /logout" do
    setup do
      {:ok, token, claims} = Guardian.encode_and_sign(DiscoveryApi.Auth.Guardian, @username)
      allow PaddleWrapper.authenticate(any(), any()), return: :does_not_matter
      allow PaddleWrapper.get(filter: any()), return: {:ok, [Helper.ldap_user()]}
      {:ok, %{user: @username, jwt: token, claims: claims}}
    end

    test "GET /logout", %{conn: conn, jwt: jwt} do
      cookie =
        conn
        |> put_req_header("authorization", "Bearer #{jwt}")
        |> put_req_cookie(Helper.default_guardian_token_key(), jwt)
        |> get("/api/v1/logout")
        |> Helper.extract_response_cookie_as_map()

      assert cookie["guardian_default_token"] == ""
    end
  end
end
