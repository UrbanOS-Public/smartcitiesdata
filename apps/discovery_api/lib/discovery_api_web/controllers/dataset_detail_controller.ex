defmodule DiscoveryApiWeb.DatasetDetailController do
  @moduledoc """
  Controller for viewing all the details of a dataset
  """
  use DiscoveryApiWeb, :controller

  def fetch_dataset_detail(conn, _params) do
    render(conn, :fetch_dataset_detail, model: conn.assigns.model)
  end
end
