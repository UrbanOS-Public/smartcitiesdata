defmodule AndiWeb.EditController do
  use AndiWeb, :controller

  def show(conn, session) do
    live_render(conn, AndiWeb.EditLiveView, session: session)
  end
end
