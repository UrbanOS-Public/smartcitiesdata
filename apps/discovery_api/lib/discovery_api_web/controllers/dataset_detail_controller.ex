defmodule DiscoveryApiWeb.DatasetDetailController do
  @moduledoc false
  use DiscoveryApiWeb, :controller

  def fetch_dataset_detail(conn, %{"dataset_id" => dataset_id}) do
    with {:ok, dataset} <- get_dataset(dataset_id),
         {:ok, organization} <- get_organization(dataset.organization) do
      render(conn, :fetch_dataset_detail, dataset: dataset, organization: organization)
    else
      {:error, :dataset_not_found} -> render_error(conn, 404, "Not Found")
      _ -> render_error(conn, 500, "Something bad happened")
    end
  end

  def get_dataset(dataset_id) do
    case DiscoveryApi.Data.Dataset.get(dataset_id) do
      nil -> {:error, :dataset_not_found}
      result -> {:ok, result}
    end
  end

  def get_organization(organization_id) do
    case DiscoveryApi.Data.Organization.get(organization_id) do
      {:error, _error} -> {:error, :organization_not_found}
      result -> result
    end
  end
end
