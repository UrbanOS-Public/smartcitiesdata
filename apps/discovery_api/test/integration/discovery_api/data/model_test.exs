defmodule DiscoveryApi.Data.ModelTest do
  use ExUnit.Case
  use Divo, services: [:ldap, :redis]
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Data.Model

  setup do
    Redix.command!(:redix, ["FLUSHALL"])
    :ok
  end

  test "Model saves data to Redis" do
    model = Helper.sample_model()
    Model.save(model)

    actual =
      Redix.command!(:redix, ["GET", "discovery-api:model:#{model.id}"])
      |> Jason.decode!(keys: :atoms)

    assert actual[:id] == model.id
    assert actual[:title] == model.title
    assert actual[:systemName] == model.systemName
    assert actual[:keywords] == model.keywords

    assert actual[:organization] == model.organization
    assert actual[:modifiedDate] == model.modifiedDate

    assert actual[:fileTypes] == model.fileTypes
    assert actual[:description] == model.description
  end

  test "get should return a single model" do
    expected_model = Helper.sample_model()
    model_json_string = to_json(expected_model)
    last_updated_date = DateTime.to_iso8601(DateTime.utc_now())

    Redix.command!(:redix, ["SET", "discovery-api:model:#{expected_model.id}", model_json_string])
    expected_model = %{expected_model | lastUpdatedDate: last_updated_date}

    Redix.command!(:redix, [
      "SET",
      "forklift:last_insert_date:#{expected_model.id}",
      last_updated_date
    ])

    Redix.command!(:redix, ["SET", "discovery-api:stats:#{expected_model.id}", expected_model.completeness])

    actual_model = Model.get(expected_model.id)
    assert actual_model == expected_model
  end

  test "get latest should return a single date" do
    last_updated_date = DateTime.to_iso8601(DateTime.utc_now())
    model_id = "123"

    Redix.command!(:redix, ["SET", "forklift:last_insert_date:#{model_id}", last_updated_date])

    actual_date = Model.get_last_updated_date(model_id)
    assert actual_date == last_updated_date
  end

  test "get should return nil when model does not exist" do
    actual_model = Model.get("123456")
    assert nil == actual_model
  end

  test "should return all of the models" do
    model_id_1 = Faker.UUID.v4()
    model_id_2 = Faker.UUID.v4()

    Enum.each(
      [Helper.sample_model(%{id: model_id_1}), Helper.sample_model(%{id: model_id_2})],
      fn model ->
        Redix.command!(:redix, ["SET", "discovery-api:model:#{model.id}", to_json(model)])
      end
    )

    expected = [model_id_1, model_id_2] |> Enum.sort()
    actual = Model.get_all() |> Enum.map(fn model -> model.id end) |> Enum.sort()

    assert expected == actual
  end

  test "get all returns empty list if no keys exist" do
    assert [] == Model.get_all()
  end

  test "get all should return the models for all the ids specified" do
    model1 = Helper.sample_model()
    model2 = Helper.sample_model()
    model3 = Helper.sample_model()

    [model1, model2, model3]
    |> Enum.each(fn model -> Redix.command!(:redix, ["SET", "discovery-api:model:#{model.id}", to_json(model)]) end)

    [model1, model2, model3]
    |> Enum.each(fn model ->
      Redix.command!(:redix, ["SET", "discovery-api:stats:#{model.id}", Jason.encode!(model.completeness)])
    end)

    results = Model.get_all([model1.id, model3.id])
    assert model1 in results
    assert model3 in results
    assert 2 == length(results)
  end

  defp to_json(model) do
    model
    |> Map.from_struct()
    |> Jason.encode!()
  end
end
