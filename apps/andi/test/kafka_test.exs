defmodule KafkaTest do
  use ExUnit.Case
  use Placebo

  alias SCOS.RegistryMessage

  setup do
    allow(Kaffe.Producer.produce_sync(any(), any(), any()), return: :ok)
    on_exit(fn -> Placebo.unstub() end)
  end

  test "send to kafka produces a kafka message when a valid dataset is sent" do
    result =
      %RegistryMessage{:id => "1", :technical => 2, :business => 3}
      |> Andi.Kafka.send_to_kafka()

    assert_called(
      Kaffe.Producer.produce_sync(
        "dataset-registry",
        "1",
        "{\"business\":3,\"id\":\"1\",\"technical\":2}"
      ),
      once()
    )

    assert result == :ok
  end

  test "send to kafka error when not using dataset struct returns error" do
    result = Andi.Kafka.send_to_kafka(%{:business => 3, :operational => 4, :id => "5"})
    assert result == {:error, "Send to kafka only suppports SCOS.RegistryMessage structs"}
  end
end
