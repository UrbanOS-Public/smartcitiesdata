defmodule DiscoveryStreams.SourceHandlerTest do
  alias RaptorServiceMock
  alias DiscoveryStreamsTelemetryEventMock
  use DiscoveryStreamsWeb.ChannelCase
  import Mox

  import Checkov

  alias DiscoveryStreams.Stream.SourceHandler

  setup :verify_on_exit!

  @dataset_1_id "d21d5af6-346c-43e5-891f-8c2c7f28e4ab"
  @dataset_2_id "555ea731-d85e-4bd8-b2e4-4017366c24b0"

  Mox.defmock(StreamingMetrics.HostnameMock, for: StreamingMetrics.Hostname)

  setup do
    # Set up dependency injection through Application environment
    Application.put_env(:discovery_streams, :brook_view_state, BrookViewStateMock)
    Application.put_env(:discovery_streams, :raptor_service, RaptorServiceMock)
    Application.put_env(:discovery_streams, :telemetry_event, DiscoveryStreamsTelemetryEventMock)
    Application.put_env(:discovery_streams, :hostname_module, StreamingMetrics.HostnameMock)
    
    BrookViewStateMock
    |> stub(:get, fn 
      _, :streaming_datasets_by_system_name, "ceav__shuttles_on_a_map" -> {:ok, @dataset_1_id}
      _, :streaming_datasets_by_system_name, "central_ohio_transit_authority__cota_stream" -> {:ok, @dataset_2_id}
      _, :streaming_datasets_by_system_name, _ -> {:error, "does_not_exist"}
    end)

    RaptorServiceMock
    |> stub(:is_authorized, fn _, _, _ -> true end)

    DiscoveryStreamsTelemetryEventMock
    |> stub(:add_event_metrics, fn _, _, _ -> :ok end)

    stub(StreamingMetrics.HostnameMock, :get, fn -> "test-hostname" end)
    
    :ok
  end

  data_test "broadcasts data from system_name #{system_name} to a websocket channel #{channel}" do

    {:ok, _, socket} =
      socket(DiscoveryStreamsWeb.UserSocket)
      |> subscribe_and_join(DiscoveryStreamsWeb.StreamingChannel, channel)

    %{"payload" => %{"vehicle" => %{"vehicle" => %{"id" => "11603"}}}}
    |> SourceHandler.handle_message(%{assigns: %{system_name: system_name}})

    assert_broadcast("update", %{"vehicle" => %{"vehicle" => %{"id" => "11603"}}})
    leave(socket)

    where([
      [:channel, :system_name],
      ["streaming:central_ohio_transit_authority__cota_stream", "central_ohio_transit_authority__cota_stream"],
      ["streaming:ceav__shuttles_on_a_map", "ceav__shuttles_on_a_map"]
    ])
  end

  test "Telemetry events are published with each handled batch" do
    # Override TelemetryEvent at the application level to bypass the real TelemetryEvent.Mock
    Application.put_env(:telemetry_event, :implementation, DiscoveryStreamsTelemetryEventMock)
    
    expect(DiscoveryStreamsTelemetryEventMock, :add_event_metrics, fn _, _, _ -> :ok end)

    [%{"payload" => %{"vehicle" => %{"vehicle" => %{"id" => "11603"}}}}]
    |> SourceHandler.handle_batch(%{dataset_id: "any_id"})
  end
end
