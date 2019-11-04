defmodule AndiWeb.DatasetController do
  use AndiWeb, :controller

  alias Andi.Services.DatasetRetrieval

  def index(conn, _params) do
    datasets = DatasetRetrieval.get_all!()

    render(conn, "index.html", datasets: datasets)
  end
end
