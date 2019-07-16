defmodule Valkyrie.BroadwayTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias SmartCity.Data

  setup do
    {:ok, broadway} = Valkyrie.Broadway.start_link([])

    [broadway: broadway]
  end

  test "should return transformed data", %{broadway: broadway} do
    schema = [
      %{name: "name", type: "string"},
      %{name: "age", type: "integer"}
    ]

    dataset = TDG.create_dataset(id: "ds1", technical: %{schema: schema})
    Valkyrie.Dataset.put(dataset)

    data = TDG.create_data(dataset_id: "ds1", payload: %{"name" => "johnny", "age" => "21"})
    kafka_message = %{value: Jason.encode!(data)}

    Broadway.test_messages(broadway, [kafka_message])

    assert_receive {:ack, _ref, messages, _}, 5_000

    payloads =
      messages
      |> Enum.map(fn message -> Data.new(message.data.value) end)
      |> Enum.map(fn {:ok, data} -> data end)
      |> Enum.map(fn data -> data.payload end)

    assert payloads == [%{"name" => "johnny", "age" => 21}]
  end

  test "should yeet message when it fails to parse properly", %{broadway: broadway} do
    allow SmartCity.Data.new(any()), return: {:error, :something_went_badly}
    allow Yeet.process_dead_letter(any(), any(), any(), any()), return: :ok

    kafka_message = %{value: :message}

    Broadway.test_messages(broadway, [kafka_message])

    assert_receive {:ack, _ref, _, [message]}, 5_000
    assert {:failed, :something_went_badly} == message.status

    assert_called Yeet.process_dead_letter("unknown", :message, "Valkyrie", reason: :something_went_badly)
  end

  test "should raise an exception when dataset is not available", %{broadway: broadway} do
  end
end

defmodule Fake.Broadway do
  use Broadway

  def start_link(opts) do
    config = Valkyrie.Broadway.broadway_config(opts)

    new_config =
      Keyword.put(config, :producers,
        default: [
          module: {Fake.Producer, []},
          stages: 1
        ]
      )

    Broadway.start_link(Valkyrie.Broadway, new_config)
  end

  def handle_message(_not, _used, state) do
    {:noreply, state}
  end
end

defmodule Fake.Producer do
  use GenStage

  def start_link([]) do
    GenStage.start_link(__MODULE__, [])
  end

  def init(_args) do
    {:producer, []}
  end

  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end

  def handle_events(events, _from, state) do
    {:noreply, events, state}
  end
end
