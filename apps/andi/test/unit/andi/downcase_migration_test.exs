defmodule Andi.DowncaseMigrationTest do
  use ExUnit.Case
  use Placebo
  alias Andi.DowncaseMigration
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.Event, only: [dataset_update: 0]

  @instance Andi.instance_name()

  test "should lower case all the column names" do
    datasetA =
      TDG.create_dataset(
        id: "123",
        technical: %{
          schema: [
            %{
              "name" => "UPPERCASE",
              "description" => "ANOTHER"
            }
          ]
        }
      )

    datasetB =
      TDG.create_dataset(
        id: "456",
        technical: %{
          schema: [
            %{
              "name" => "BIGNAME",
              "description" => "ANOTHER1"
            }
          ]
        }
      )

    expected_schemaA = [
      %{
        "name" => "uppercase",
        "another_field" => "ANOTHER"
      }
    ]

    expected_schemaB = [
      %{
        "name" => "bigname",
        "another_field" => "ANOTHER1"
      }
    ]

    # expected_datasetA = datasetA |> Map.from_struct() |> put_in([:technical, :schema], expected_schemaA) |> SmartCity.Dataset.new()
    # expected_datasetB = datasetB |> Map.from_struct() |> put_in([:technical, :schema], expected_schemaB) |> SmartCity.Dataset.new()

    expected_datasetA = with_updated_schema(datasetA, expected_schemaA)
    expected_datasetB = with_updated_schema(datasetB, expected_schemaB)

    allow(Brook.get_all_values!(@instance, :dataset), return: [datasetA, datasetB])
    allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)
    allow(Brook.ViewState.merge(:dataset, any(), any()), return: :ok)

    Andi.DowncaseMigration.do_migration()

    assert_called(Brook.Event.send(@instance, dataset_update(), :andi, expected_datasetA))
    assert_called(Brook.ViewState.merge(:dataset, datasetA.id, expected_datasetA))

    assert_called(Brook.Event.send(@instance, dataset_update(), :andi, expected_datasetB))
    assert_called(Brook.ViewState.merge(:dataset, datasetB.id, expected_datasetB))
  end

  defp with_updated_schema(dataset, new_schema) do
    updated_technical =
      dataset.technical
      |> Map.from_struct()
      |> Map.put(:schema, new_schema)

    dataset_map =
      dataset
      |> Map.from_struct()

    {:ok, dataset} =
      dataset_map
      |> Map.put(:technical, updated_technical)
      |> Map.put(:business, Map.from_struct(dataset.business))
      |> SmartCity.Dataset.new()

    dataset
  end

  # test "should update the view state" do
  # end

  # test "should post dataset definition update" do
  # end

  # test "should mark viewstate migration success" do
  # end

  # test "should migrate all the dataset" do
  # end
end
