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

      expected = %{"123" => %{"0.1" => %{:record_count => 1, "id" => 1}}}

      allow(Dataset.get!(dataset.id), return: dataset)
      assert expected == Quality.reducer(data, %{})
    end

    test "with existing accumulator", %{simple_dataset: dataset} do
      data_override = %{dataset_id: "123", payload: %{"id" => "123", "name" => "John Smith"}}

      data = TDG.create_data(data_override)

      allow(Dataset.get!(dataset.id), return: dataset)

      assert %{"123" => %{"0.1" => %{:record_count => 2, "id" => 2}}} ==
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

      assert %{"123" => %{"0.1" => %{:record_count => 3, "id" => 2}}} ==
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
        "456" => %{"0.1" => %{:record_count => 1, "id" => 1}},
        "123" => %{"0.1" => %{:record_count => 1, "id" => 0}},
        "789" => %{"0.1" => %{:record_count => 1, "id" => 1}}
      }

      assert expected ==
               Enum.reduce(messages, %{}, &Quality.reducer/2)
    end

    test "different versions", %{simple_dataset: dataset} do
      data1 =
        TDG.create_data(%{dataset_id: "123", payload: %{"id" => "123", "name" => "George Lucas"}})
        |> Map.update!(:version, fn _ -> "1.0" end)

      data2 =
        TDG.create_data(%{dataset_id: "123", payload: %{"name" => "John Williams"}})
        |> Map.update!(:version, fn _ -> "1.1" end)

      data3 =
        TDG.create_data(%{dataset_id: "123", payload: %{"id" => "123"}})
        |> Map.update!(:version, fn _ -> "1.2" end)

      allow(Dataset.get!("123"), return: dataset)

      messages = [data1, data2, data3]

      expected = %{
        "123" => %{
          "1.0" => %{:record_count => 1, "id" => 1},
          "1.1" => %{:record_count => 1, "id" => 0},
          "1.2" => %{:record_count => 1, "id" => 1}
        }
      }

      assert expected ==
               Enum.reduce(messages, %{}, &Quality.reducer/2)
    end

    test "with nested schema accumulator", %{dataset: dataset} do
      data_override = %{
        dataset_id: "abc",
        version: "1.0",
        payload: %{
          "required field" => "123",
          "required parent field" => %{
            "required sub field" => "jim",
            "next_of_kin" => %{"required_sub_schema_field" => "bob"}
          }
        }
      }

      data = TDG.create_data(data_override)

      expected = %{
        "abc" => %{
          "0.1" => %{
            :record_count => 1,
            "required field" => 1,
            "required parent field" => 1,
            "required parent field.required sub field" => 1,
            "required parent field.next_of_kin" => 1,
            "required parent field.next_of_kin.required_sub_schema_field" => 1
          }
        }
      }

      allow(Dataset.get!(dataset.id), return: dataset)
      assert expected == Quality.reducer(data, %{})
    end
  end

  describe "do thing" do
    test "thing" do
      input =
        {"abc",
         %{
           "0.1" => %{
             :record_count => 5,
             :fields => %{
               "id" => 1,
               "name" => 2,
               "super" => 3,
               "happy" => 4,
               "fun time" => 5
             }
           }
         }}

      # input =
      #   {"abc",
      #    %{
      #      "0.1" => %{
      #        :record_count => 5,
      #        "id" => 1,
      #        "name" => 2,
      #        "super" => 3,
      #        "happy" => 4,
      #        "fun time" => 5
      #      }
      #    }}

      expected =
        {"abc",
         [
           %{
             dataset_id: "abc",
             schema_version: "0.1",
             field: "fun time",
             valid_values: 5,
             records: 5
           },
           %{
             dataset_id: "abc",
             schema_version: "0.1",
             field: "happy",
             valid_values: 4,
             records: 5
           },
           %{
             dataset_id: "abc",
             schema_version: "0.1",
             field: "id",
             valid_values: 1,
             records: 5
           },
           %{
             dataset_id: "abc",
             schema_version: "0.1",
             field: "name",
             valid_values: 2,
             records: 5
           },
           %{
             dataset_id: "abc",
             schema_version: "0.1",
             field: "super",
             valid_values: 3,
             records: 5
           }
         ]}

      assert expected == Quality.calculate_quality(input)
    end
  end
end
