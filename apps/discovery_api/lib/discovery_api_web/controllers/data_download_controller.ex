defmodule DiscoveryApiWeb.DataDownloadController do
  use DiscoveryApiWeb, :controller
  alias DiscoveryApi.Services.PrestoService
  alias DiscoveryApi.Services.ObjectStorageService
  alias DiscoveryApiWeb.Plugs.{GetModel, RecordMetrics}
  alias DiscoveryApiWeb.DataView
  alias DiscoveryApiWeb.Utilities.HmacToken
  alias DiscoveryApiWeb.Utilities.ParamUtils
  require Logger

  plug(GetModel)
  plug(:conditional_accepts, DataView.accepted_formats() when action in [:fetch_file])
  plug(RecordMetrics, fetch_file: "downloads")

  @not_found_error_message "File not found or you do not have access to the data"

  defp conditional_accepts(conn, formats) do
    if conn.assigns.model.sourceType == "host" do
      DiscoveryApiWeb.Plugs.Acceptor.call(conn, [])
    else
      Phoenix.Controller.accepts(conn, formats)
    end
  end

  def fetch_file(conn, params) do
    fetch_file(conn, params, get_format(conn))
  end

  def fetch_file(conn, params, possible_extensions) when is_list(possible_extensions) do
    model = conn.assigns.model
    dataset_id = model.id
    path = "#{model.organizationDetails.orgName}/#{model.name}"

    authorized =
      if System.get_env("REQUIRE_API_KEY") == "true" do
        validate_hmac_token(params)
      else
        model.private == false || validate_hmac_token(params)
      end

    if authorized do
      case ObjectStorageService.download_file_as_stream(path, possible_extensions) do
        {:ok, data_stream, extension} ->
          resp_as_stream(conn, data_stream, extension, dataset_id, true)

        _ ->
          render_error(conn, 406, "File not available in the specified format")
      end
    else
      render_error(conn, 404, @not_found_error_message)
    end
  end

  def fetch_file(
        %{assigns: %{model: %{private: true, id: dataset_id}}} = conn,
        %{"expires" => expires, "key" => key},
        format
      ) do
    dataset_name = conn.assigns.model.systemName
    schema = conn.assigns.model.schema

    parsed_expires = ParamUtils.safely_parse_int(expires)

    if HmacToken.valid_hmac_token(key, dataset_id, parsed_expires) do
      data_stream =
        DiscoveryApi.prestige_opts()
        |> Prestige.new_session()
        |> Prestige.stream!("select #{PrestoService.format_select_statement_from_schema(schema)} from #{dataset_name}")
        |> Stream.flat_map(&Prestige.Result.as_maps/1)
        |> map_schema?(schema, format)

      rendered_data_stream =
        DataView.render_as_stream(:data, format, %{
          stream: data_stream,
          columns: [],
          dataset_name: dataset_name,
          schema: schema
        })

      resp_as_stream(conn, rendered_data_stream, format, dataset_id)
    else
      render_error(conn, 404, @not_found_error_message)
    end
  end

  def fetch_file(%{assigns: %{model: %{private: true}}} = conn, _, _),
    do: render_error(conn, 404, @not_found_error_message)

  def fetch_file(conn, params, format) do
    dataset_name = conn.assigns.model.systemName
    dataset_id = conn.assigns.model.id
    schema = conn.assigns.model.schema

    authorized =
      if System.get_env("REQUIRE_API_KEY") == "true" do
        validate_hmac_token(params)
      else
        true
      end

    if authorized do
      data_stream =
        DiscoveryApi.prestige_opts()
        |> Prestige.new_session()
        |> Prestige.stream!(
          "select #{if format == "json" or format == "geojson", do: PrestoService.format_select_statement_from_schema(schema), else: "*"} from #{
            dataset_name
          }"
        )
        |> Stream.flat_map(&Prestige.Result.as_maps/1)
        |> map_schema?(schema, format)

      rendered_data_stream =
        DataView.render_as_stream(:data, format, %{
          stream: data_stream,
          columns: [],
          dataset_name: dataset_name,
          schema: schema
        })

      resp_as_stream(conn, rendered_data_stream, format, dataset_id)
    else
      render_error(conn, 404, @not_found_error_message)
    end
  end

  def validate_hmac_token(params) do
    key = params["key"]
    dataset_id = params["dataset_id"]
    expires = params["expires"] || "0"
    integer_expires = String.to_integer(expires)
    HmacToken.valid_hmac_token(key, dataset_id, integer_expires)
  end

  defp map_schema?(data, schema, format) do
    if format == "json" || format == "geojson", do: PrestoService.map_prestige_results_to_schema(data, schema), else: data
  end
end
