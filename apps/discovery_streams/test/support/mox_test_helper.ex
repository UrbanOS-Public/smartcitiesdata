defmodule DiscoveryStreams.MoxTestHelper do
  @moduledoc """
  Test helper for setting up Mox mocks
  """
  
  import Mox

  def verify_mocks do
    verify!()
  end

  def setup_mocks do
    Application.ensure_all_started(:discovery_streams)
    
    # Set up the mocks
    setup_discovery_streams_supervisor_mock()
    setup_brook_mocks()
    setup_elsa_mocks()
    setup_raptor_service_mocks()
    
    :ok
  end

  defp setup_discovery_streams_supervisor_mock do
    DiscoveryStreams.Stream.Supervisor.Mock
    |> stub(:start_child, fn _dataset_id -> :ok end)
    |> stub(:terminate_child, fn _dataset_id -> :ok end)
  end

  defp setup_brook_mocks do
    Brook.Event
    |> stub(:new, fn opts -> struct(Brook.Event, opts) end)
    
    Brook
    |> stub(:get_all, fn _view, _collection -> {:ok, %{}} end)
    |> stub(:get, fn _view, _collection, _key -> {:error, "not found"} end)
  end

  defp setup_elsa_mocks do
    Elsa
    |> stub(:delete_topic, fn _endpoints, _topic -> :ok end)
  end

  defp setup_raptor_service_mocks do
    RaptorService
    |> stub(:is_authorized, fn _url, _api_key, _system_name -> true end)
    |> stub(:get_user_id_from_api_key, fn _url, _api_key -> {:ok, "test-user-id"} end)
  end
end