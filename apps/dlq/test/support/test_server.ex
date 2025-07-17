defmodule Dlq.TestServer do
  @moduledoc """
  Test implementation of Dlq.Server that doesn't try to connect to Kafka.
  This allows tests to run without actual Kafka connections.
  """
  use GenServer

  # API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def ensure_topic(endpoints, topic) do
    GenServer.call(__MODULE__, {:ensure_topic, endpoints, topic})
  end
  
  def start_producer(config) do
    GenServer.call(__MODULE__, {:start_producer, config})
  end
  
  def produce(connection, topic, messages) do
    GenServer.call(__MODULE__, {:produce, connection, topic, messages})
  end

  # GenServer callbacks
  
  def init(_) do
    # Store test-specific state
    {:ok, %{
      calls: [],
      endpoints: :endpoints,
      topic: :topic
    }}
  end
  
  def handle_cast({:write, dead_letters}, state) do
    messages = Enum.map(dead_letters, &Jason.encode!/1)
    produce(:elsa_dlq, state.topic, messages)
    {:noreply, state}
  end
  
  def handle_call({:ensure_topic, endpoints, topic}, _from, state) do
    # Forward call to the mock
    result = Dlq.Test.ElsaMock.topic?(endpoints, topic)
    if !result do
      Dlq.Test.ElsaMock.create_topic(endpoints, topic)
    end
    
    {:reply, :ok, state}
  end
  
  def handle_call({:start_producer, config}, _from, state) do
    # Forward call to the mock
    result = Dlq.Test.ElsaSupervisorMock.start_link(config)
    {:reply, result, state}
  end
  
  def handle_call({:produce, connection, topic, messages}, _from, state) do
    # Forward call to the mock
    result = Dlq.Test.ElsaMock.produce(connection, topic, messages)
    {:reply, result, state}
  end
end