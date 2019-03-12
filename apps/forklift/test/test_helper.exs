Application.ensure_all_started(:logger)
Application.ensure_all_started(:placebo)

children = [{Registry, keys: :unique, name: Forklift.Registry}]
opts = [strategy: :one_for_one, name: Forklift.Supervisor]
Supervisor.start_link(children, opts)

ExUnit.start()
Faker.start()

defmodule Helper do
  def make_kafka_message(value, topic) do
    %{
      topic: topic,
      value: value |> Jason.encode!()
    }
  end
end
