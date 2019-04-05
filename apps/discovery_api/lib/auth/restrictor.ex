defmodule DiscoveryApi.Auth.Restrictor do
  require Logger
  import Plug.Conn
  alias DiscoveryApi.Auth.Guardian

  alias SmartCity.Organization
  alias DiscoveryApi.Data.Dataset

  def init(default), do: default

  def call(conn, _) do
    %{"dataset_id" => dataset_id} = conn |> Map.get(:path_params)
    token = Plug.Conn.get_req_header(conn, "token") |> List.first()

    if is_authorized?(token, dataset_id) do
      conn
    else
      conn
      |> DiscoveryApiWeb.RenderError.render_error(401, "Not Authorized")
      |> halt()
    end
  end

  def is_authorized?(token, dataset_id) do
    with dataset when not is_nil(dataset) <- Dataset.get(dataset_id),
         :restricted <- dataset_restricted(dataset),
         {:ok, claims} <- Guardian.decode_and_verify(token),
         {:ok, resource} <- Guardian.resource_from_claims(claims),
         groups <- extract_groups(resource) do
      organization = dataset.organizationDetails

      Enum.member?(groups, organization.dn)
    else
      :unrestricted ->
        true

      {:error, error} ->
        Logger.error(inspect(error))
        false

      unhandled ->
        Logger.error(inspect(unhandled))
        false
    end
  end

  defp dataset_restricted(dataset) do
    if dataset.private do
      :restricted
    else
      :unrestricted
    end
  end

  defp extract_groups(resource) do
    Map.get(resource, "memberOf", [])
    |> Enum.map(&extract_group/1)
  end

  defp extract_group(group) do
    group
    |> String.split(",")
    |> List.first()
    |> String.split("=")
    |> List.last()
  end
end
