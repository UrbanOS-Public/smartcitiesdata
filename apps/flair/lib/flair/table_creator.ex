defmodule Flair.TableCreator do
  @moduledoc """
  Creates the table that Flair will insert stats into then stops, or else crashes, stopping the whole application.

  In this case we block the whole application because Flair cannot run without a table to put its data into.
  """
  use GenServer, restart: :transient
  use Retry

  # Times in milliseconds
  @initial_delay 10_000
  @delay_step 10_000
  @max_retries 20

  def start_link(init_arg, opts \\ []) do
    GenServer.start_link(__MODULE__, init_arg, opts)
  end

  def init(_init_arg) do
    retry with: linear_backoff(@initial_delay, @delay_step) |> Stream.take(@max_retries),
          rescue_only: [Prestige.ConnectionError, Prestige.Error] do
      Flair.PrestoClient.get_create_timing_table_statement()
      |> Flair.PrestoClient.execute()
    after
      _ -> nil
    else
      _ -> raise RuntimeError, message: "Could not create Presto table. Shutting down."
    end

    {:ok, nil, {:continue, nil}}
  end

  def handle_continue(_continue, _state) do
    {:stop, :normal, nil}
  end
end
