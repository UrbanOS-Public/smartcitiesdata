defmodule DeadLetter.Application do
  @moduledoc false
  use Application

  def start(_something, _else) do
    opts = Application.get_all_env(:dead_letter)
    config = Keyword.fetch!(opts, :driver) |> Enum.into(%{init_args: [size: 3000]})
    IO.inspect(config, label: "Dead Letter Config")

    children =
      [
        {config.module, config.init_args},
        {DeadLetter.Server, config}
      ]
      |> List.flatten()

    Supervisor.start_link(children, strategy: :one_for_one, name: DeadLetter.Supervisor)
  end
end
