# defmodule Estuary.EventHandler do
#   @moduledoc false
#   # use Brook.Event.Handler

#   alias SmartCity.Dataset
#   alias Estuary.DataWriter

#   @reader Application.get_env(:estuary, :topic_reader)

#   import SmartCity.Event, only: [data_ingest_start: 0, dataset_update: 0, data_ingest_end: 0]

#   def handle_event(messages) do
#     messages
#     |> Enum.map(&parse_message_value/1)
#   end

#   defp parse_message_value(message) do
#     message.value
#     |> Jason.decode()
#     |> process_message()
#   end

#   defp process_message(
#          {:ok, %{"author" => _, "create_ts" => _, "data" => _, "type" => _} = event}
#        ) do
#     init_args <- reader_args(event)
#     :ok = @reader.init(init_args)
#     DataWriter.write(event)
#   end

#   defp process_message({_, term}) do
#     :discard
#   end

#   defp reader_args(event) do
#     [
#       instance: instance_name(),
#       connection: Application.get_env(:estuary, :connection),
#       endpoints: Application.get_env(:estuary, :elsa_brokers),
#       topic: Application.get_env(:estuary, :event_stream_topic),
#       handler: Estuary.MessageHandler,
#       handler_init_args: [dataset: event],
#       topic_subscriber_config: Application.get_env(:estuary, :topic_subscriber_config, []),
#       retry_count: Application.get_env(:estuary, :retry_count),
#       retry_delay: Application.get_env(:estuary, :retry_initial_delay)
#     ]
#   end
# end
