defmodule DeadLetter.Supervisor do
  @moduledoc """
  DeadLetter application supervisor. Orchestrates and monitors
  the server and driver processes.
  """
  use Supervisor
  @default_driver %{module: DeadLetter.Driver.Default, init_args: []}

  @doc """
  Start a DeadLetter supervisor and link it to the current process
  """
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Initialize the DeadLetter supervisor with all the necessary
  configurations for starting its children.
  """
  def init(opts) do
    config = Keyword.get(opts, :driver, @default_driver) |> Enum.into(%{})

    children =
      [
        {config.module, config.init_args},
        {DeadLetter.Server, config}
      ]
      |> List.flatten()

    Supervisor.init(children, strategy: :one_for_one)
  end
end
