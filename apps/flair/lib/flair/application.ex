defmodule Flair.Application do
  @moduledoc """
  Flair starts flows for any profiling needed, as well as a connection to kafka.
  """
  use Application

  def start(_type, _args) do
    children = 
      case Mix.env() do
        :test -> []
        _ -> [{Flair.Durations.Flow, []}, {Flair.Durations.Init, []}]
      end
    
    Supervisor.start_link(children, strategy: :one_for_one, name: Flair.Supervisor)
  end
end
