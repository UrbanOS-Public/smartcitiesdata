defmodule DiscoveryApiWeb.DatasetDetailController do
  @moduledoc false
  use DiscoveryApiWeb, :controller

  def fetch_dataset_detail(conn, _params) do
    render(conn, :fetch_dataset_detail, dataset: conn.assigns.dataset)
  end
end
