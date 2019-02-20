defmodule Forklift do

  #   CREATE TABLE hive.default.pirate_dilemma5 (
  #     go bigint,
  #     fund varchar,
  #     yourself varchar
  #  )
  #  WITH (
  #     format = 'ORC'
  #  )

  def make_pirate_dilemna do
    %{
      payload: %{
        go: :rand.uniform(999_999),
        fund: Faker.Industry.sector(),
        yourself: Faker.Superhero.name()
      },
      metadata: %{dataset_id: "pirate_dilemma#{:rand.uniform(5)}"}
    }
    |> Jason.encode!()
  end

  def send_to_kafka(msg) do
    Kaffe.Producer.produce_sync("streaming-transformed", [{"the_key", msg}])
  end

  def produce_message do
    make_pirate_dilemna()
    |> send_to_kafka()
  end

  def produce_messages(x) do
    Enum.each(1..x, &(Forklift.produce_message() || &1))
  end
end
