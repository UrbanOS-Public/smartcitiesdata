defmodule Valkyrie.DatasetMutationTest do
  use ExUnit.Case
  use Divo
  import SmartCity.TestHelper

  alias SmartCity.TestDataGenerator, as: TDG

  @dataset_id "ds1"
  @input_topic "#{Application.get_env(:valkyrie, :input_topic_prefix)}-#{@dataset_id}"
  @output_topic "#{Application.get_env(:valkyrie, :output_topic_prefix)}-#{@dataset_id}"
  @endpoints Application.get_env(:valkyrie, :elsa_brokers)

  test "a dataset with an updated schema properly parses new messages" do
    schema = [%{name: "age", type: "string"}]
    dataset = TDG.create_dataset(id: @dataset_id, technical: %{schema: schema})

    data1 = TDG.create_data(dataset_id: @dataset_id, payload: %{"age" => "21"})

    SmartCity.Dataset.write(dataset)
    Elsa.create_topic(@endpoints, @output_topic)

    Elsa.produce(@endpoints, @input_topic, Jason.encode!(data1), partition: 0)

    eventually(
      fn ->
        messages = Elsa.Fetch.fetch_stream(@endpoints, @output_topic) |> Enum.into([])

        payloads =
          Enum.map(messages, fn message -> SmartCity.Data.new(message.value) |> elem(1) |> Map.get(:payload) end)

        assert payloads == [%{"age" => "21"}]
      end,
      2_000,
      20
    )

    updated_dataset = %{dataset | technical: %{dataset.technical | schema: [%{name: "age", type: "integer"}]}}
    SmartCity.Dataset.write(updated_dataset)

    Process.sleep(2_000)

    data2 = TDG.create_data(dataset_id: @dataset_id, payload: %{"age" => "22"})
    Elsa.produce(@endpoints, @input_topic, Jason.encode!(data2), partition: 0)

    eventually(
      fn ->
        messages = Elsa.Fetch.fetch_stream(@endpoints, @output_topic) |> Enum.into([])

        payloads =
          Enum.map(messages, fn message -> SmartCity.Data.new(message.value) |> elem(1) |> Map.get(:payload) end)

        assert payloads == [%{"age" => "21"}, %{"age" => 22}]
      end,
      2_000,
      10
    )
  end
end
