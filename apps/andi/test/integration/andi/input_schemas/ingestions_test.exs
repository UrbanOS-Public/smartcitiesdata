defmodule Andi.InputSchemas.IngestionsTest do
  use ExUnit.Case
  use Andi.DataCase

  @moduletag shared_data_connection: true

  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.Ingestion
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.ExtractStep

  describe "get_all/0" do
    test "given existing ingestions, it returns them with extract steps and schema preloaded" do
      dataset_one = TDG.create_dataset(%{})
      dataset_two = TDG.create_dataset(%{})

      assert {:ok, _} = Datasets.update(dataset_one)
      assert {:ok, _} = Datasets.update(dataset_two)

      ingestion_one = TDG.create_ingestion(%{targetDataset: dataset_one.id})
      ingestion_two = TDG.create_ingestion(%{targetDataset: dataset_two.id})

      assert {:ok, _} = Ingestions.update(ingestion_one)
      assert {:ok, _} = Ingestions.update(ingestion_two)

      assert [%{extractSteps: [%{id: _} | _], schema: [%{id: _} | _]} | _] = Ingestions.get_all()
    end
  end

  describe "get/1" do
    test "given an existing ignestion, it returns it, preloaded" do
      dataset = TDG.create_dataset(%{})
      assert {:ok, _} = Datasets.update(dataset)

      ingestion = TDG.create_ingestion(%{targetDataset: dataset.id})

      {:ok,
       %{
         id: ingestion_id,
         name: name,
         targetDataset: target_dataset,
         extractSteps: [%{id: extract_steps_id} | _],
         schema: [%{id: schema_id} | _]
       } = _andi_ingestion} = Ingestions.update(ingestion)

      assert %{
               id: ^ingestion_id,
               name: ^name,
               targetDataset: ^target_dataset,
               extractSteps: [%{id: ^extract_steps_id} | _],
               schema: [%{id: ^schema_id} | _]
             } = Ingestions.get(ingestion.id)
    end

    test "given a non-existing ingestion, it returns nil" do
      assert nil == Ingestions.get(UUID.uuid4())
    end
  end

  describe "create/0" do
    test "given no parameters, creates a blank Andi ingestion with a random UUID" do
      new_ingestion = Ingestions.create()
      assert is_binary(new_ingestion.id)
      assert new_ingestion.targetDataset == nil
      assert Ingestions.get(new_ingestion.id).id == new_ingestion.id
    end
  end

  describe "delete/1" do
    test "given an existing ingestion, it cascade deletes it" do
      dataset = TDG.create_dataset(%{})
      assert {:ok, _} = Datasets.update(dataset)
      ingestion = TDG.create_ingestion(%{targetDataset: dataset.id})

      {:ok,
       %{id: ingestion_id, targetDataset: target_dataset, extractSteps: [%{id: extract_steps_id} | _], schema: [%{id: schema_id} | _]} =
         _andi_ingestion} = Ingestions.update(ingestion)

      assert %{
               id: ^ingestion_id,
               targetDataset: ^target_dataset,
               extractSteps: [%{id: ^extract_steps_id} | _],
               schema: [%{id: ^schema_id} | _]
             } = Ingestions.get(ingestion.id)

      assert {:ok, _} = Ingestions.delete(ingestion.id)
      assert nil == Andi.Repo.get(Ingestion, ingestion_id)
      assert nil == Andi.Repo.get(ExtractStep, extract_steps_id)
      assert nil == Andi.Repo.get(DataDictionary, schema_id)
    end
  end

  describe "update/1" do
    test "given a newly seen smart city ingestion, turns it into an Andi ingestion" do
      dataset = TDG.create_dataset(%{})
      assert {:ok, _} = Datasets.update(dataset)
      ingestion = TDG.create_ingestion(%{targetDataset: dataset.id})

      assert {:ok, _} = Ingestions.update(ingestion)
    end

    test "given a newly seen smart city ingestion, does not save it into an Andi ingestion unless it is associated with a dataset" do
      ingestion = TDG.create_ingestion(%{})

      assert {:error, ingestion_changeset} = Ingestions.update(ingestion)
      refute ingestion_changeset.valid?

      assert ingestion_changeset.errors == [
               targetDataset: {"does not exist", [constraint: :foreign, constraint_name: "ingestions_targetDataset_fkey"]}
             ]
    end

    test "given an existing smart city ingestion, updates it" do
      dataset = TDG.create_dataset(%{})
      assert {:ok, _} = Datasets.update(dataset)
      ingestion = TDG.create_ingestion(%{targetDataset: dataset.id})
      original_topLevelSelector = ingestion.topLevelSelector

      assert {:ok, %Ingestion{topLevelSelector: ^original_topLevelSelector} = andi_ingestion} = Ingestions.update(ingestion)

      original_ingestion_id = andi_ingestion.id

      updated_ingestion = put_in(ingestion, [:topLevelSelector], "$.Penny.Floofer")

      assert {:ok,
              %Ingestion{
                id: ^original_ingestion_id,
                topLevelSelector: "$.Penny.Floofer"
              }} = Ingestions.update(updated_ingestion)
    end

    test "given a blank extract step body, retains it" do
      dataset = TDG.create_dataset(%{})
      assert {:ok, _} = Datasets.update(dataset)

      smrt_ingestion =
        TDG.create_ingestion(%{
          targetDataset: dataset.id,
          extractSteps: [
            %{
              type: "auth",
              context: %{
                url: "123.com",
                body: "",
                headers: %{"api-key" => "to-my-heart"}
              }
            }
          ]
        })

      {:ok, ingestion} = Ingestions.update(smrt_ingestion)
      step = ingestion.extractSteps |> Enum.at(0)
      assert step.context.body == ""
    end
  end

  describe "update_cadence/2" do
    test "given an ingestion id and a cadence, the cadence is successfully updated" do
      dataset = TDG.create_dataset(%{})
      assert {:ok, _} = Datasets.update(dataset)
      ingestion = TDG.create_ingestion(%{targetDataset: dataset.id, cadence: "never"})
      assert {:ok, %Ingestion{cadence: "never"} = _} = Ingestions.update(ingestion)

      new_cadence = "once"
      Ingestions.update_cadence(ingestion.id, new_cadence)

      assert %Ingestion{cadence: "once"} = Ingestions.get(ingestion.id)
    end
  end

  defp delete_in(data, path) do
    pop_in(data, path) |> elem(1)
  end
end
