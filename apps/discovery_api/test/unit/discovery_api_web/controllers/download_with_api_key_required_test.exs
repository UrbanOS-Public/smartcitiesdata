defmodule DiscoveryApiWeb.DownloadWithApiKeyRequiredTest do
  use DiscoveryApiWeb.Test.AuthConnCase.UnitCase
  import Mox
  use Properties, otp_app: :discovery_api

  alias DiscoveryApi.Services.ObjectStorageService
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Test.Helper

  @object_storage_service Application.compile_env(:discovery_api, :object_storage_service)
  @model Application.compile_env(:discovery_api, :model)
  @prestige Application.compile_env(:discovery_api, :prestige)
  @prestige_result Application.compile_env(:discovery_api, :prestige_result)

  @dataset_id "1234-4567-89101"
  @system_name "foobar__company_data"
  @org_name "org1"
  @data_name "data1"
  @data_map [%{"id" => 1, "int_array" => [2, 3, 4]}]
  @data_stream ["id,int_array\n1,\"2,3,4\"\n"]

  @expected_failure_message "{\"message\":\"File not found or you do not have access to the data\"}"
  @expected_response_body "id,int_array\n1,\"2,3,4\"\n"

  getter(:presign_key, generic: true)
  getter(:download_link_expire_seconds, generic: true)

  setup do
    on_exit(fn -> System.put_env("REQUIRE_API_KEY", "false") end)
    System.put_env("REQUIRE_API_KEY", "true")

    stub(@object_storage_service, :download_file_as_stream, fn _, _ ->
      {:ok, @data_stream, "csv"}
    end)

    stub(@prestige, :new_session, fn _ -> :connection end)
    stub(@prestige, :stream!, fn _, _ -> Stream.map(@data_map, &{:ok, &1}) end)
    stub(@prestige_result, :as_maps, fn _ -> @data_map end)
    :ok
  end

  describe "when api keys are required, downloading a public dataset" do
    test "with extensions will succeed with a valid hmac token and expires", %{anonymous_conn: conn} do
      model = build_model_with_extensions(private: false)
      dataset_id = @dataset_id
      stub(@model, :get, fn ^dataset_id -> model end)
      expires = build_expires()
      hmac = build_hmac_token(expires)
      url = "/api/v1/dataset/#{@dataset_id}/download?key=#{hmac}&expires=#{expires}"

      response = conn |> get(url)

      assert response.status === 200
      assert response.resp_body === @expected_response_body
    end

    test "with extensions will fail without an hmac token", %{anonymous_conn: conn} do
      model = build_model_with_extensions(private: false)
      dataset_id = @dataset_id
      stub(@model, :get, fn ^dataset_id -> model end)
      url = "/api/v1/dataset/#{@dataset_id}/download"

      response = conn |> get(url)

      assert response.status === 404
      assert response.resp_body === @expected_failure_message
    end

    test "with requested format will succeed with a valid token and expires", %{anonymous_conn: conn} do
      model = build_model(private: false)
      dataset_id = @dataset_id
      stub(@model, :get, fn ^dataset_id -> model end)
      expires = build_expires()
      hmac = build_hmac_token(expires)
      url = "/api/v1/dataset/#{@dataset_id}/download?key=#{hmac}&expires=#{expires}"

      response = conn |> get(url)

      assert response.status === 200
      assert response.resp_body === @expected_response_body
    end

    test "with requested format will fail without an hmac token", %{anonymous_conn: conn} do
      model = build_model(private: false)
      dataset_id = @dataset_id
      stub(@model, :get, fn ^dataset_id -> model end)
      url = "/api/v1/dataset/#{@dataset_id}/download"

      response = conn |> get(url)

      assert response.status === 404
      assert response.resp_body === @expected_failure_message
    end
  end

  describe "when api keys are required, downloading a private dataset" do
    test "with extensions will succeed with a valid hmac token and expires", %{anonymous_conn: conn} do
      model = build_model_with_extensions(private: true)
      dataset_id = @dataset_id
      stub(@model, :get, fn ^dataset_id -> model end)
      expires = build_expires()
      hmac = build_hmac_token(expires)
      url = "/api/v1/dataset/#{@dataset_id}/download?key=#{hmac}&expires=#{expires}"

      response = conn |> get(url)

      assert response.status === 200
      assert response.resp_body === @expected_response_body
    end

    test "with extensions will fail without an hmac token", %{anonymous_conn: conn} do
      model = build_model_with_extensions(private: true)
      dataset_id = @dataset_id
      stub(@model, :get, fn ^dataset_id -> model end)
      url = "/api/v1/dataset/#{@dataset_id}/download"

      response = conn |> get(url)

      assert response.status === 404
      assert response.resp_body === @expected_failure_message
    end

    test "with requested format will succeed with a valid token and expires", %{anonymous_conn: conn} do
      model = build_model(private: true)
      dataset_id = @dataset_id
      stub(@model, :get, fn ^dataset_id -> model end)
      expires = build_expires()
      hmac = build_hmac_token(expires)
      url = "/api/v1/dataset/#{@dataset_id}/download?key=#{hmac}&expires=#{expires}&_format=csv"

      response = conn |> get(url)

      assert response.status === 200
      assert response.resp_body === @expected_response_body
    end

    test "with requested format will fail without an hmac token", %{anonymous_conn: conn} do
      model = build_model(private: true)
      dataset_id = @dataset_id
      stub(@model, :get, fn ^dataset_id -> model end)
      url = "/api/v1/dataset/#{@dataset_id}/download"

      response = conn |> get(url)

      assert response.status === 404
      assert response.resp_body === @expected_failure_message
    end
  end

  defp build_model_with_extensions(private: private) do
    Helper.sample_model(%{
      id: @dataset_id,
      systemName: @system_name,
      name: @data_name,
      private: private,
      lastUpdatedDate: nil,
      queries: 7,
      downloads: 9,
      sourceType: "host",
      organizationDetails: %{
        orgName: @org_name
      },
      schema: [
        %{name: "bob", type: "integer"},
        %{name: "andi", type: "integer"}
      ]
    })
  end

  defp build_model(private) do
    Helper.sample_model(%{
      id: @dataset_id,
      systemName: @system_name,
      name: @data_name,
      private: private,
      lastUpdatedDate: nil,
      queries: 7,
      downloads: 9,
      organizationDetails: %{
        orgName: @org_name
      },
      schema: [
        %{name: "bob", type: "integer"},
        %{name: "andi", type: "integer"}
      ]
    })
  end

  defp build_expires() do
    expires_in_seconds = download_link_expire_seconds()
    DateTime.utc_now() |> DateTime.add(expires_in_seconds, :second) |> DateTime.to_unix()
  end

  defp build_hmac_token(expires) do
    key = presign_key()
    :crypto.mac(:hmac, :sha256, key, "#{@dataset_id}/#{expires}") |> Base.encode16()
  end
end
