defmodule Valkyrie.DatasetTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG

  @cache Valkyrie.Dataset.cache_name()

  setup do
    Cachex.clear(@cache)
    :ok
  end

  describe "get/1" do
    test "When a dataset exists but not in the cache, we add it to the cache" do
      dataset = TDG.create_dataset(id: "id-1", technical: %{schema: [%{"name" => "my_int", "type" => "int"}]})
      allow SmartCity.Dataset.get(any()), return: {:ok, dataset}, meck_options: [:passthrough]
      expected_struct = %Valkyrie.Dataset{schema: [%{"name" => "my_int", "type" => "int"}]}

      result = Valkyrie.Dataset.get("id-1")

      assert result == expected_struct
      assert Cachex.get!(@cache, "id-1") == expected_struct
    end

    test "When a key is in the local cache, dataset is not called" do
      allow SmartCity.Dataset.get(any()), return: {:ok, :doesnt_matter}
      dataset = %Valkyrie.Dataset{schema: [%{"name" => "my_int", "type" => "int"}]}
      Cachex.put(@cache, "id-1", dataset)

      assert Valkyrie.Dataset.get("id-1") == dataset
      refute_called SmartCity.Dataset.get(any())
    end

    test "When dataset is not available get returns nil" do
      allow SmartCity.Dataset.get(any()), return: {:error, %SmartCity.Dataset.NotFound{}}
      assert nil == Valkyrie.Dataset.get("id-1")
    end
  end

  describe "put/1" do
    test "saves struct to local cache" do
      dataset = TDG.create_dataset(id: "id1", technical: %{schema: [%{"name" => "my_int", "type" => "int"}]})
      Valkyrie.Dataset.put(dataset)

      assert Cachex.get!(@cache, "id1") == %Valkyrie.Dataset{schema: [%{"name" => "my_int", "type" => "int"}]}
    end
  end
end
