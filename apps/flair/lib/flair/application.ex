defmodule Flair.Application do
  @moduledoc """
  Flair starts flows for any profiling needed, as well as a connection to kafka.
  """
  use Application

  def start(_type, _args) do
    [{Flair.Durations.Flow, []}, {Flair.Durations.Init, []}]
    |> Supervisor.start_link(strategy: :one_for_one, name: Flair.Supervisor)
  end
end
