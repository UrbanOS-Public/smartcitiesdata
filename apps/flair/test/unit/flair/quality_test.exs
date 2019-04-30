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

  describe "reducer/1" do
    test "with empty accumulator", %{simple_dataset: dataset} do
      data_override = %{dataset_id: "123", payload: %{"id" => "123", "name" => "John Smith"}}

      data = TDG.create_data(data_override)

      expected = %{
        :window_start => "start_time",
        "123" => %{"0.1" => %{record_count: 1, window_start: "start_time", fields: %{"id" => 1}}}
      }

      allow(Dataset.get!(dataset.id), return: dataset)
      assert expected == Quality.reducer(data, %{window_start: "start_time"})
    end

    test "with existing accumulator", %{simple_dataset: dataset} do
      data_override = %{dataset_id: "123", payload: %{"id" => "123", "name" => "John Smith"}}

      data = TDG.create_data(data_override)

      allow(Dataset.get!(dataset.id), return: dataset)

      assert %{
               "123" => %{
                 "0.1" => %{record_count: 2, window_start: "start_time", fields: %{"id" => 2}}
               },
               window_start: "start_time"
             } ==
               Quality.reducer(data, Quality.reducer(data, %{window_start: "start_time"}))
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

      assert %{
               "123" => %{
                 "0.1" => %{record_count: 3, window_start: "start_time", fields: %{"id" => 2}}
               },
               window_start: "start_time"
             } ==
               Enum.reduce(messages, %{window_start: "start_time"}, &Quality.reducer/2)
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

      dataset2 = simple_overrides |> TDG.create_dataset() |> Map.put(:id, "456")
      dataset3 = simple_overrides |> TDG.create_dataset() |> Map.put(:id, "789")

      allow(Dataset.get!("123"), return: dataset)
      allow(Dataset.get!("456"), return: dataset2)
      allow(Dataset.get!("789"), return: dataset3)

      expected = %{
        "456" => %{"0.1" => %{record_count: 1, window_start: "start_time", fields: %{"id" => 1}}},
        "123" => %{"0.1" => %{record_count: 1, window_start: "start_time", fields: %{"id" => 0}}},
        "789" => %{"0.1" => %{record_count: 1, window_start: "start_time", fields: %{"id" => 1}}},
        window_start: "start_time"
      }

      assert expected ==
               Enum.reduce(messages, %{window_start: "start_time"}, &Quality.reducer/2)
    end

    test "different versions", %{simple_dataset: dataset} do
      data_map1 = %{dataset_id: "123", payload: %{"id" => "123", "name" => "George Lucas"}}
      data_map2 = %{dataset_id: "123", payload: %{"name" => "John Williams"}}
      data_map3 = %{dataset_id: "123", payload: %{"id" => "123"}}

      data1 =
        data_map1
        |> TDG.create_data()
        |> Map.update!(:version, fn _ -> "1.0" end)

      data2 =
        data_map2
        |> TDG.create_data()
        |> Map.update!(:version, fn _ -> "1.1" end)

      data3 =
        data_map3
        |> TDG.create_data()
        |> Map.update!(:version, fn _ -> "1.2" end)

      allow(Dataset.get!("123"), return: dataset)

      messages = [data1, data2, data3]

      expected = %{
        :window_start => "start_time",
        "123" => %{
          "1.0" => %{record_count: 1, window_start: "start_time", fields: %{"id" => 1}},
          "1.1" => %{record_count: 1, window_start: "start_time", fields: %{"id" => 0}},
          "1.2" => %{record_count: 1, window_start: "start_time", fields: %{"id" => 1}}
        }
      }

      assert expected ==
               Enum.reduce(messages, %{window_start: "start_time"}, &Quality.reducer/2)
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
        :window_start => "start_time",
        "abc" => %{
          "0.1" => %{
            record_count: 1,
            window_start: "start_time",
            fields: %{
              "required field" => 1,
              "required parent field" => 1,
              "required parent field.required sub field" => 1,
              "required parent field.next_of_kin" => 1,
              "required parent field.next_of_kin.required_sub_schema_field" => 1
            }
          }
        }
      }

      allow(Dataset.get!(dataset.id), return: dataset)
      assert expected == Quality.reducer(data, %{window_start: "start_time"})
    end

    test "returns existing accumulator and yeets when data message errors" do
      data_override = %{dataset_id: "123", payload: %{"id" => "123", "name" => "John Smith"}}

      data = TDG.create_data(data_override)

      allow(Dataset.get!(any()), return: nil)
      allow(Yeet.process_dead_letter(any(), any(), any()), return: :ok)

      acc = %{
        "123" => %{
          "0.1" => %{record_count: 2, window_start: "start_time", fields: %{"id" => 2}}
        },
        window_start: "start_time"
      }

      assert acc == Quality.reducer(data, acc)
      assert_called(Yeet.process_dead_letter(any(), any(), any()), once())
    end
  end

  describe "calculate_quality/1" do
    test "breaks window into individual events" do
      allow(DateTime.to_iso8601(any()), return: "xyz")
      allow(DateTime.utc_now(), return: "stu")

      input =
        {"abc",
         %{
           "0.1" => %{
             :record_count => 5,
             :window_start => "abc",
             :fields => %{
               "id" => 1,
               "name" => 2,
               "super" => 3,
               "happy" => 4,
               "fun time" => 5
             }
           }
         }}

      expected =
        {"abc",
         [
           %{
             dataset_id: "abc",
             schema_version: "0.1",
             field: "fun time",
             window_start: "abc",
             window_end: "xyz",
             valid_values: 5,
             records: 5
           },
           %{
             dataset_id: "abc",
             schema_version: "0.1",
             field: "happy",
             window_start: "abc",
             window_end: "xyz",
             valid_values: 4,
             records: 5
           },
           %{
             dataset_id: "abc",
             schema_version: "0.1",
             field: "id",
             window_start: "abc",
             window_end: "xyz",
             valid_values: 1,
             records: 5
           },
           %{
             dataset_id: "abc",
             schema_version: "0.1",
             field: "name",
             window_start: "abc",
             window_end: "xyz",
             valid_values: 2,
             records: 5
           },
           %{
             dataset_id: "abc",
             schema_version: "0.1",
             field: "super",
             window_start: "abc",
             window_end: "xyz",
             valid_values: 3,
             records: 5
           }
         ]}

      assert expected == Quality.calculate_quality(input)
    end
  end
end
