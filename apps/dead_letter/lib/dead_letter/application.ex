defmodule DeadLetter.Application do
  use Application

  def start(_something, _else) do
    opts = Application.get_all_env(:dead_letter)
    config = Keyword.fetch!(opts, :driver) |> Enum.into(%{})

    children =
      [
        {config.module, config.init_args},
        {DeadLetter.Server, config}
      ]
      |> List.flatten()

    Supervisor.start_link(children, strategy: :one_for_one, name: DeadLetter.Supervisor)
  end
end
