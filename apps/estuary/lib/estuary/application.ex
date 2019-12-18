defmodule Estuary.Application do
  @moduledoc false
  use Application

  alias Estuary.DataWriter
  alias Estuary.Datasets.DatasetSchema

  @spec start(any, any) :: {:error, any} | {:ok, pid}
  def start(_type, _args) do
<<<<<<< HEAD
    if elsa_endpoint() != nil do
      validate_topic_exists()
      EventTable.create_schema()
      EventTable.create_table()
    end
    # SC - Starts
=======
    validate_topic_exists()

>>>>>>> Adding unit test and faker
    DatasetSchema.table_schema()
    |> DataWriter.init()
    # SC - Ends
    children = get_children()

    opts = [strategy: :one_for_one, name: Estuary.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp elsa_options do
    [
      endpoints: elsa_endpoint(),
      connection: :estuary_elsa,
      producer: [topic: event_stream_topic()],
      group_consumer: [
        group: "estuary-consumer-group",
        topics: [event_stream_topic()],
        handler: Estuary.MessageHandler,
        config: [
          begin_offset: :earliest,
          offset_reset_policy: :reset_to_earliest
        ]
      ]
    ]
  end

  defp validate_topic_exists do
    case Elsa.Topic.exists?(
           elsa_endpoint(),
           event_stream_topic()
         ) do
      true ->
        :ok

      false ->
        Elsa.Topic.create(
          elsa_endpoint(),
          event_stream_topic()
        )
    end
  end

  defp elsa_endpoint do
    Application.get_env(:estuary, :elsa_endpoint)
  end

  defp event_stream_topic do
    Application.get_env(:estuary, :event_stream_topic)
  end

  defp get_children do
    if elsa_endpoint() != nil do
      [
        {Elsa.Supervisor, elsa_options()}
      ]
    else
      []
    end
  end
end
