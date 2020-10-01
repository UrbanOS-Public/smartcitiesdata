defmodule Valkyrie.SourceHandlerTest do
  use ExUnit.Case
  use Placebo

  import SmartCity.Data, only: [end_of_data: 0]
  import SmartCity.Event, only: [data_standardization_end: 0]
  alias SmartCity.TestDataGenerator, as: TDG

  @current_time "2019-07-17T14:45:06.123456Z"

  setup do
    allow SmartCity.Data.Timing.current_time(), return: @current_time, meck_options: [:passthrough]
    :ok
  end

  describe "handle_message/2" do
    test "should return standardized data" do
      {data, schema} = create_data_message()
      assert {:ok, handled} = Valkyrie.Stream.SourceHandler.handle_message(data, %{assigns: %{schema: schema}})

      assert handled.payload == %{"name" => "johnny", "age" => 21}
    end

    test "applies valkyrie message timing" do
      Application.put_env(:valkyrie, :profiling_enabled, true)
      {data, schema} = create_data_message()

      assert {:ok, handled} = Valkyrie.Stream.SourceHandler.handle_message(data, %{assigns: %{schema: schema}})
      timing = Enum.find(handled.operational.timing, fn timing -> timing.app == "valkyrie" end)

      assert timing == %SmartCity.Data.Timing{
                app: "valkyrie",
                end_time: @current_time,
                label: "timing",
                start_time: @current_time
              }
    end

    test "should return empty timing when profiling status is not true" do
      Application.put_env(:valkyrie, :profiling_enabled, false)
      {data, schema} = create_data_message()

      assert {:ok, handled} = Valkyrie.Stream.SourceHandler.handle_message(data, %{assigns: %{schema: schema}})
      refute Enum.find(handled.operational.timing, fn timing -> timing.app == "valkyrie" end)
    end

    test "should emit a data standarization end event when END_OF_DATA message is recieved" do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :does_not_matter)
      {_data, schema} = create_data_message()
      dataset_id = Faker.UUID.v4()

      assert {:ok, handled} = Valkyrie.Stream.SourceHandler.handle_message(end_of_data(), %{dataset_id: dataset_id, assigns: %{schema: schema}})

      assert_called(Brook.Event.send(any(), data_standardization_end(), any(), %{"dataset_id" => dataset_id}))
    end
  end

  # test "should yeet message when it fails to parse properly", %{broadway: broadway} do
  #   allow SmartCity.Data.new(any()), return: {:error, :something_went_badly}

  #   kafka_message = %{value: :message}

  #   Broadway.test_batch(broadway, [kafka_message])

  #   assert_receive {:ack, _ref, _, [message]}, 5_000
  #   assert {:failed, :something_went_badly} == message.status

  #   eventually(fn ->
  #     {:ok, dlqd_message} = DeadLetter.Carrier.Test.receive()
  #     refute dlqd_message == :empty

  #     assert dlqd_message.app == "Valkyrie"
  #     assert dlqd_message.dataset_id == @dataset_id
  #     assert dlqd_message.reason == :something_went_badly
  #   end)
  # end

  # test "should yeet message if standardizing data fails due to schmear validation", %{broadway: broadway} do
  #   data = TDG.create_data(dataset_id: @dataset_id, payload: %{"name" => "johnny", "age" => "twenty-one"})
  #   kafka_message = %{value: Jason.encode!(data)}

  #   Broadway.test_batch(broadway, [kafka_message])

  #   assert_receive {:ack, _ref, _, failed_messages}, 5_000
  #   assert 1 == length(failed_messages)

  #   eventually(fn ->
  #     {:ok, dlqd_message} = DeadLetter.Carrier.Test.receive()
  #     refute dlqd_message == :empty

  #     assert dlqd_message.app == "Valkyrie"
  #     assert dlqd_message.dataset_id == "ds1"
  #     assert dlqd_message.reason == %{"age" => :invalid_integer}
  #     assert dlqd_message.error == :failed_schema_validation
  #     assert dlqd_message.original_message == Jason.encode!(data)
  #   end)
  # end


  defp create_data_message() do
    data = TDG.create_data(dataset_id: Faker.UUID.v4(), payload: %{"name" => "johnny", "age" => "21"}, operational: %{timing: []})
    schema = [
      %{
        name: "name",
        type: "string"
      },
      %{
        name: "age",
        type: "integer"
      }
    ]

    {data, schema}
  end
end
