defmodule Flair.QualityTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG
  alias Flair.Quality

  setup do
    {:ok,
     dataset: TestHelper.create_dataset(),
     simple_dataset: TestHelper.create_simple_dataset(),
     simple_overrides: TestHelper.create_simple_dataset_overrides()}
  end

  describe "quality_reducer" do
    test "with empty accumulator", %{simple_dataset: dataset} do
      data_override = %{dataset_id: "123", payload: %{"id" => "123", "name" => "John Smith"}}

      data = TDG.create_data(data_override)

      expected = %{"123" => %{:record_count => 1, "id" => 1}}

      allow(Dataset.get!(dataset.id), return: dataset)
      assert expected == Quality.reducer(data, %{})
    end

    test "with existing accumulator", %{simple_dataset: dataset} do
      data_override = %{dataset_id: "123", payload: %{"id" => "123", "name" => "John Smith"}}

      data = TDG.create_data(data_override)

      allow(Dataset.get!(dataset.id), return: dataset)

      assert %{"123" => %{:record_count => 2, "id" => 2}} ==
               Quality.reducer(data, Quality.reducer(data, %{}))
    end

    test "three messages", %{simple_dataset: dataset} do
      data_overrides = [
        %{dataset_id: "123", payload: %{"id" => "123", "name" => "John Smith"}},
        %{dataset_id: "123", payload: %{"name" => "John Smith"}},
        %{dataset_id: "123", payload: %{"id" => "123"}}
      ]

      messages =
        data_overrides
        |> Enum.map(fn override -> TDG.create_data(override) end)

      allow(Dataset.get!(dataset.id), return: dataset)

      assert %{"123" => %{:record_count => 3, "id" => 2}} ==
               Enum.reduce(messages, %{}, &Quality.reducer/2)
    end

    test "different dataset_ids", %{simple_dataset: dataset, simple_overrides: simple_overrides} do
      data_overrides = [
        %{dataset_id: "456", payload: %{"id" => "123", "name" => "George Lucas"}},
        %{dataset_id: "123", payload: %{"name" => "John Williams"}},
        %{dataset_id: "789", payload: %{"id" => "123"}}
      ]

      messages =
        data_overrides
        |> Enum.map(fn override -> TDG.create_data(override) end)

      dataset2 = TDG.create_dataset(simple_overrides) |> Map.put(:id, "456")
      dataset3 = TDG.create_dataset(simple_overrides) |> Map.put(:id, "789")

      allow(Dataset.get!("123"), return: dataset)
      allow(Dataset.get!("456"), return: dataset2)
      allow(Dataset.get!("789"), return: dataset3)

      expected = %{
        "456" => %{:record_count => 1, "id" => 1},
        "123" => %{:record_count => 1, "id" => 0},
        "789" => %{:record_count => 1, "id" => 1}
      }

      assert expected ==
               Enum.reduce(messages, %{}, &Quality.reducer/2)
    end

    # test "with nested schema accumulator", %{dataset: dataset} do
    #   data_override = %{
    #     dataset_id: "abc",
    #     payload: %{
    #       "required field" => "123",
    #       "required parent field" => %{
    #         "required sub field" => "jim",
    #         "next_of_kin" => %{"required_sub_schema_field" => "bob"}
    #       }
    #     }
    #   }

    #   data = TDG.create_data(data_override)

    #   expected = %{
    #     "123" => %{
    #       :record_count => 1,
    #       "required field" => 1,
    #       "required parent field" => 1,
    #       "required parent field.required sub field" => 1,
    #       "required parent field.required sub field.next_of_kin" => 1,
    #       "required parent field.required sub field.next_of_kin.required_sub_schema_field" => 1
    #     }
    #   }

    #   allow(Dataset.get!(dataset.id), return: dataset)
    #   assert expected == Quality.reducer(data, %{})
    # end
  end
end
