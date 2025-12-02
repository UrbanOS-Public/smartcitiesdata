defmodule DeadLetter.Application do
  @moduledoc false
  use Application
  require Logger

  def start(_something, _else) do
    Logger.info("======================================================")
    Logger.info("DeadLetter.Application starting...")
    Logger.info("======================================================")

    opts = Application.get_all_env(:dead_letter)

    Logger.info("DeadLetter raw configuration:")
    Logger.info("  All env keys: #{inspect(Keyword.keys(opts))}")
    Logger.info("  Full config: #{inspect(opts, pretty: true)}")

    case Keyword.fetch(opts, :driver) do
      {:ok, driver_config} ->
        Logger.info("DeadLetter driver configuration found:")
        Logger.info("  Driver config: #{inspect(driver_config, pretty: true)}")

        config = Enum.into(driver_config, %{init_args: [size: 3000]})

        Logger.info("DeadLetter final configuration:")
        Logger.info("  Module: #{inspect(config.module)}")
        Logger.info("  Init args: #{inspect(config.init_args)}")

        start_supervisor(config)

      :error ->
        error_msg = """
        FATAL: DeadLetter configuration error - :driver key not found

        Available configuration keys: #{inspect(Keyword.keys(opts))}
        Full configuration: #{inspect(opts, pretty: true)}

        Required configuration format:
          config :dead_letter,
            driver: [
              module: DeadLetter.Carrier.Kafka,
              init_args: [
                endpoints: [localhost: 9092],
                topic: "dead-letters"
              ]
            ]

        Please check:
        1. config/runtime.exs exists and is being loaded (MIX_ENV=prod)
        2. Environment variables are set correctly:
           - KAFKA_BROKERS (default: localhost:9092)
           - DEAD_LETTER_TOPIC (default: streaming-dead-letters)
        3. The release was built with the latest configuration
        """

        Logger.error(error_msg)
        raise KeyError, key: :driver, term: opts, message: error_msg
    end
  end

  defp start_supervisor(config) do
    Logger.info("Starting DeadLetter supervisor with driver: #{inspect(config.module)}")

    children =
      [
        {config.module, config.init_args},
        {DeadLetter.Server, config}
      ]
      |> List.flatten()

    result = Supervisor.start_link(children, strategy: :one_for_one, name: DeadLetter.Supervisor)

    case result do
      {:ok, pid} ->
        Logger.info("DeadLetter.Application started successfully (pid: #{inspect(pid)})")
        Logger.info("======================================================")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("DeadLetter.Application failed to start: #{inspect(reason)}")
        Logger.error("======================================================")
        {:error, reason}
    end
  end
end
