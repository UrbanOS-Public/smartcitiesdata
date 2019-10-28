defmodule AndiWeb.DatasetPageController do
  use AndiWeb, :controller

  import Andi, only: [instance_name: 0]

  require Logger

  def index(conn, _params) do
    {:ok, datasets} = Brook.get_all_values(instance_name(), :dataset)

    render(conn, "index.html", datasets: datasets)
  end
end
