defmodule Pipeline.Writer.S3Writer do
  alias Pipeline.Writer.S3Writer
  alias Pipeline.Writer.TableWriter.{Compaction, Statement}
  alias Pipeline.Application
  alias ExAws.S3

  require Logger
  @type schema() :: [map()]

  @impl Pipeline.Writer
  @spec init(table: String.t(), schema: schema()) :: :ok | {:error, term()}
  def init(args) do
    config = parse_args(args)

    with {:ok, statement} <- Statement.create(config),
         {:ok, _} <- execute(statement) do
      Logger.info("Created #{config.table} table")
      :ok
    else
      error ->
        Logger.error("Error creating #{config.table} table: #{inspect(error)}")
        {:error, "Write to Presto failed: #{inspect(error)}"}
    end
  end

  @impl Pipeline.Writer
  @spec write([term()], table: String.t(), schema: schema()) :: :ok | {:error, term()}
  @doc """
  Writes data to PrestoDB table.
  """
  def write([], config) do
    table = Keyword.fetch!(config, :table)
    Logger.debug("No data to write to #{table}")
    :ok
  end

  def write(content, config) do
    args = parse_args(config)

    payloads = Enum.map(content, &Map.get(&1, :payload))

    json_data = payloads
    |> Enum.map(&S3Writer.S3SafeJson.build(&1, args[:schema]))
    |> Enum.map(&Jason.encode!/1)
    |> Enum.join("\n")

    File.write!(args[:table], json_data, [:compressed])

    time = DateTime.utc_now |> DateTime.to_unix |> to_string()
    file_name = "hive-s3/#{args[:table]}/#{time}-#{System.unique_integer}.gz"
    args[:table]
    |> S3.Upload.stream_file()
    |> S3.upload("kdp-cloud-storage", file_name)
    |> ExAws.request()
    |> IO.inspect(label: "s3_writer.ex:49")
    |> case do
      {:ok, _} -> :ok
      error -> {:error, error}
    end
  end

  defp parse_args(args) do
    %{
      table: Keyword.fetch!(args, :table) <> "__json",
      schema: Keyword.fetch!(args, :schema),
      format: "JSON"
    }
  end

  defp execute(statement) do
    try do
      Application.prestige_opts() |> Prestige.new_session() |> Prestige.execute(statement)
    rescue
      e -> e
    end
  end
end
