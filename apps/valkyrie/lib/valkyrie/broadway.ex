defmodule Valkyrie.Broadway do
  @producer_module Application.get_env(:valkyrie, :broadway_producer_module, OffBroadway.Kafka.Producer)

  alias Broadway.Message

  def start_link(opts) do
    Broadway.start_link(__MODULE__, broadway_config(opts))
  end

  defp broadway_config(opts) do
    output_topic = "something"
    producer_name = "producer"
    name = "name"

    [
      name: :"#{name}_broadway",
      producers: [
        default: [
          module: {@producer_module, opts},
          stages: 1
        ]
      ],
      processors: [
        default: [
          stages: processor_stages()
        ]
      ],
      batchers: [
        default: [
          stages: batch_stages(),
          batch_size: batch_size(),
          batch_timeout: batch_timeout()
        ]
      ],
      context: %{
        output_topic: output_topic,
        producer: producer_name
      }
    ]
  end

  def handle_message(_processor, %Message{data: data} = message, context) do
    with {:ok, parsed_value} <- SmartCity.Data.new(data.value) do
      dataset = Valkyrie.Dataset.get(parsed_value.dataset_id)
      {:ok, standardized_payload} = Valkyrie.standardize_data(dataset, parsed_value.payload)

      new_value =
        %{parsed_value | payload: standardized_payload}
        |> Jason.encode!()

      %{message | data: %{data | value: new_value}}
    else
      {:error, reason} ->
        Yeet.process_dead_letter("unknown", data.value, "Valkyrie", reason: reason)
        Message.failed(message, reason)
    end
  end

  def handle_batch(_batch, messages, _batch_info, context) do
    messages
  end

  defp endpoints(), do: Application.get_env(:voltron, :elsa_brokers)
  defp processor_stages(), do: Application.get_env(:voltron, :processor_stages, 1)
  defp batch_stages(), do: Application.get_env(:voltron, :batch_stages, 1)
  defp batch_size(), do: Application.get_env(:voltron, :batch_size, 1_000)
  defp batch_timeout(), do: Application.get_env(:voltron, :batch_timeout, 2_000)
end
