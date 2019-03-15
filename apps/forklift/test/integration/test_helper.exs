ExUnit.start()
Faker.start()

defmodule Helper do
  def make_kafka_message(value, topic) do
    %{
      topic: topic,
      value: value |> Jason.encode!(),
      offset: :rand.uniform(999)
    }
  end
end
