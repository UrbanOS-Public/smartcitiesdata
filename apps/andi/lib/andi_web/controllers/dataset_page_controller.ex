defmodule AndiWeb.DatasetPageController do
  use AndiWeb, :controller

  import Andi, only: [instance_name: 0]

  require Logger

  alias Andi.Services.DatasetRetrieval

  def index(conn, _params) do
    {:ok, datasets} = DatasetRetrieval.get_all()

    render(conn, "index.html", datasets: datasets)
  end
end
