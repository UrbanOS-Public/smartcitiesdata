defmodule DiscoveryStreams.StreamSubscriber do
  use Annotated.Retry
  use Properties, otp_app: :discovery_streams

  @max_retries get_config_value(:max_retries, default: 50)

  def subscribe_to_dataset(dataset) do
    start_source(dataset)
  end

  @retry with: exponential_backoff(100) |> take(@max_retries)
  defp start_source(dataset) do
    context =
      Source.Context.new!(
        handler: DiscoveryStreams.Stream.SourceHandler,
        app_name: :discovery_streams,
        dataset_id: dataset.id,
        assigns: %{
          dataset: dataset,
          # TODO: cache: Broadcast.Cache.Registry.via(load.destination.name),
          kafka: %{
            offset_reset_policy: :reset_to_latest
          }
        }
      )

    Source.start_link(Kafka.Topic.new!(endpoints: [localhost: 9092], name: "transformed-#{dataset.id}"), context)
  end
end
