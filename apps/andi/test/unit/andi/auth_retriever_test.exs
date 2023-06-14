defmodule AuthRetrieverTest do
  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.Collections.Extractions

  @ingestion_id "123"
  @dataset_id "some-dataset"
  @auth_response Jason.encode!(%{"api_key" => "12343523423423"})

  describe "authorize/6" do
    test "retrieve response using auth headers and url" do
      bypass = Bypass.open()
      url = "http://localhost:#{bypass.port}/auth"

      headers = %{
        "key1" => "value1",
        "key2" => "value2"
      }

      Bypass.expect_once(bypass, "POST", "/auth", fn conn ->
        assert "value1" == Plug.Conn.get_req_header(conn, "key1") |> List.last()
        assert "value2" == Plug.Conn.get_req_header(conn, "key2") |> List.last()
        Plug.Conn.resp(conn, 200, @auth_response)
      end)

      assert Andi.AuthRetriever.authorize(@ingestion_id, url, "body", "encode-method", headers) ==
               @auth_response
    end

    test "retrieve response when auth headers is a list" do
      bypass = Bypass.open()
      url = "http://localhost:#{bypass.port}/auth"

      headers = [
        {:key1, "value1"},
        {:key2, "value2"}
      ]

      Bypass.expect_once(bypass, "POST", "/auth", fn conn ->
        assert "value1" == Plug.Conn.get_req_header(conn, "key1") |> List.last()
        assert "value2" == Plug.Conn.get_req_header(conn, "key2") |> List.last()
        Plug.Conn.resp(conn, 200, @auth_response)
      end)

      assert Andi.AuthRetriever.authorize(@ingestion_id, url, "body", "encode-method", headers) ==
               @auth_response
    end

    test "retrieve response using auth body and url" do
      bypass = Bypass.open()
      url = "http://localhost:#{bypass.port}/auth"

      expected_body = %{
        secret_thing: "secret"
      }

      Bypass.expect_once(bypass, "POST", "/auth", fn conn ->
        {:ok, actual_body, _} = Plug.Conn.read_body(conn)
        assert actual_body == URI.encode_query(expected_body)
        assert "application/x-www-form-urlencoded" == Plug.Conn.get_req_header(conn, "content-type") |> List.last()

        Plug.Conn.resp(conn, 200, @auth_response)
      end)

      assert Andi.AuthRetriever.authorize(
               @ingestion_id,
               url,
               URI.encode_query(expected_body),
               "encode-method",
               %{}
             ) ==
               @auth_response
    end

    test "retrieve response with json encoded body" do
      bypass = Bypass.open()
      url = "http://localhost:#{bypass.port}/auth"

      expected_body = %{secret_thing: "secret"}

      Bypass.expect_once(bypass, "POST", "/auth", fn conn ->
        {:ok, actual_body, _} = Plug.Conn.read_body(conn)
        assert "application/json" == Plug.Conn.get_req_header(conn, "content-type") |> List.last()
        assert actual_body == Jason.encode!(expected_body)
        Plug.Conn.resp(conn, 200, @auth_response)
      end)

      assert Andi.AuthRetriever.authorize(@ingestion_id, url, Jason.encode!(expected_body), "json", %{}) ==
               @auth_response
    end
  end
end
