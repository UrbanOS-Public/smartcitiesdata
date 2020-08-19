defmodule DiscoveryStreams.SourceHandlerTest do
  use DiscoveryStreamsWeb.ChannelCase
  use Placebo

  import Checkov
  import ExUnit.CaptureLog

  alias DiscoveryStreams.Stream.SourceHandler
  alias SmartCity.TestDataGenerator, as: TDG

  @dataset_1_id "d21d5af6-346c-43e5-891f-8c2c7f28e4ab"
  @dataset_2_id "555ea731-d85e-4bd8-b2e4-4017366c24b0"

  setup do
    allow(Brook.get(any(), :streaming_datasets_by_id, @dataset_1_id),
      return: {:ok, "ceav__shuttles_on_a_map"}
    )

    allow(Brook.get(any(), :streaming_datasets_by_id, @dataset_2_id),
      return: {:ok, "central_ohio_transit_authority__cota_stream"}
    )

    allow(Brook.get(any(), :streaming_datasets_by_system_name, any()),
      return: {:error, "does_not_exist"}
    )

    allow(Brook.get(any(), :streaming_datasets_by_system_name, "ceav__shuttles_on_a_map"),
      return: {:ok, @dataset_1_id}
    )

    allow(Brook.get(any(), :streaming_datasets_by_system_name, "central_ohio_transit_authority__cota_stream"),
      return: {:ok, @dataset_2_id}
    )

    :ok
  end

  data_test "broadcasts data from dataset_id #{dataset_id} to a websocket channel #{channel}" do
    {:ok, _, socket} =
      socket(DiscoveryStreamsWeb.UserSocket)
      |> subscribe_and_join(DiscoveryStreamsWeb.StreamingChannel, channel)

    %{"payload" => %{"vehicle" => %{"vehicle" => %{"id" => "11603"}}}}
    |> SourceHandler.handle_message(%{dataset_id: dataset_id})

    assert_broadcast("update", %{"vehicle" => %{"vehicle" => %{"id" => "11603"}}})
    leave(socket)

    where([
      [:channel, :dataset_id],
      ["streaming:central_ohio_transit_authority__cota_stream", "555ea731-d85e-4bd8-b2e4-4017366c24b0"],
      ["streaming:ceav__shuttles_on_a_map", "d21d5af6-346c-43e5-891f-8c2c7f28e4ab"]
    ])
  end

  test "Telemetry events are published with each handled batch" do
    expect(TelemetryEvent.add_event_metrics(any(), [:records], value: %{count: any()}), return: :ok)
    [%{"payload" => %{"vehicle" => %{"vehicle" => %{"id" => "11603"}}}}]
    |> SourceHandler.handle_batch(%{dataset_id: "any_id"})
  end
end
