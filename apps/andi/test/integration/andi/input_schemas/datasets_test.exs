defmodule Andi.InputSchemas.DatasetsTest do
  use ExUnit.Case
  use Andi.DataCase

  @moduletag shared_data_connection: true

  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Business
  alias Andi.InputSchemas.Datasets.Technical
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.Organizations

  setup do
    smrt_org = TDG.create_organization(%{})
    Organizations.update(smrt_org)
    [org_id: smrt_org.id]
  end

  describe "is_unique/3" do
    test "given an existing dataset with the same system name it returns false", %{org_id: org_id} do
      dataset = TDG.create_dataset(%{organization_id: org_id})
      {:ok, _andi_dataset} = Datasets.update(dataset)
      org = Organizations.get(org_id)
      refute Datasets.is_unique?(UUID.uuid4(), dataset.technical.dataName, org.orgName)
    end

    test "given an existing dataset with the same system name and id it returns true", %{org_id: org_id} do
      dataset = TDG.create_dataset(%{organization_id: org_id})
      {:ok, _andi_dataset} = Datasets.update(dataset)
      org = Organizations.get(org_id)
      assert Datasets.is_unique?(dataset.id, dataset.technical.dataName, org.orgName)
    end
  end

  describe "remove_source_query_param/2" do
    test "given an existing source query param, it deletes it", %{org_id: org_id} do
      dataset =
        TDG.create_dataset(%{
          organization_id: org_id,
          technical: %{
            sourceUrl: "http://example.com?foo=baz&riz=bar",
            sourceQueryParams: %{"foo" => "baz", "riz" => "bar"}
          }
        })

      {:ok,
       %{
         technical: %{
           sourceUrl: "http://example.com?foo=baz&riz=bar",
           sourceQueryParams: [%{id: original_id, key: "foo", value: "baz"}, %{id: the_other_id}]
         }
       } = _andi_dataset} = Datasets.update(dataset)

      assert {:ok,
              %{technical: %{sourceUrl: "http://example.com?riz=bar", sourceQueryParams: [%{id: ^the_other_id, key: "riz", value: "bar"}]}}} =
               Datasets.remove_source_query_param(dataset.id, original_id)
    end

    test "given a non-existing source query param, it returns unaltered query params", %{org_id: org_id} do
      dataset = TDG.create_dataset(%{organization_id: org_id, technical: %{sourceQueryParams: %{"dog" => "cat"}}})

      {:ok, %{technical: %{sourceQueryParams: [existing_query_param]}} = _andi_dataset} = Datasets.update(dataset)

      missing_id = UUID.uuid4()
      assert {:ok, %{technical: %{sourceQueryParams: [^existing_query_param]}}} = Datasets.remove_source_query_param(dataset.id, missing_id)
    end

    test "removes error from changeset when an invalid query param is removed", %{org_id: org_id} do
      dataset = TDG.create_dataset(%{organization_id: org_id, technical: %{sourceQueryParams: %{}, sourceType: "remote"}})

      {:ok, andi_dataset} = Datasets.update(dataset)

      {:ok, %{technical: %{sourceQueryParams: [%{id: invalid_param_id}]}} = invalid_dataset} =
        put_in(andi_dataset, [:technical, :sourceQueryParams], [%{key: "", value: "missing key"}])
        |> Datasets.update()

      changeset = InputConverter.andi_dataset_to_full_ui_changeset(invalid_dataset)

      refute changeset.valid?

      assert {:ok, fixed_dataset} = Datasets.remove_source_query_param(invalid_dataset.id, invalid_param_id)

      changeset = InputConverter.andi_dataset_to_full_ui_changeset(fixed_dataset)

      assert changeset.valid?
    end
  end

  describe "remove_source_header/2" do
    test "given an existing source header, it deletes it", %{org_id: org_id} do
      dataset =
        TDG.create_dataset(%{organization_id: org_id, technical: %{sourceHeaders: %{"api-key" => "to-my-heart", "some_other" => "one"}}})

      {:ok, %{technical: %{sourceHeaders: [%{id: original_id, key: "api-key", value: "to-my-heart"}, %{id: the_other_id}]}} = _andi_dataset} =
        Datasets.update(dataset)

      assert {:ok, %{technical: %{sourceHeaders: [%{id: ^the_other_id, key: "some_other", value: "one"}]}}} =
               Datasets.remove_source_header(dataset.id, original_id)
    end

    test "given a non-existing source header, it returns an error", %{org_id: org_id} do
      dataset = TDG.create_dataset(%{organization_id: org_id, technical: %{sourceHeaders: %{"bumble" => "bee"}}})

      {:ok, %{technical: %{sourceHeaders: [existing_headers]}} = _andi_dataset} = Datasets.update(dataset)

      missing_id = UUID.uuid4()
      assert {:ok, %{technical: %{sourceHeaders: [^existing_headers]}}} = Datasets.remove_source_header(dataset.id, missing_id)
    end

    test "removes error from changeset when an invalid header is removed", %{org_id: org_id} do
      dataset = TDG.create_dataset(%{organization_id: org_id, technical: %{sourceHeaders: %{}, sourceType: "remote"}})

      {:ok, andi_dataset} = Datasets.update(dataset)

      {:ok, %{technical: %{sourceHeaders: [%{id: invalid_header_id}]}} = invalid_dataset} =
        put_in(andi_dataset, [:technical, :sourceHeaders], [%{key: "", value: "missing key"}])
        |> Datasets.update()

      changeset = InputConverter.andi_dataset_to_full_ui_changeset(invalid_dataset)

      refute changeset.valid?

      assert {:ok, fixed_dataset} = Datasets.remove_source_header(invalid_dataset.id, invalid_header_id)

      changeset = InputConverter.andi_dataset_to_full_ui_changeset(fixed_dataset)

      assert changeset.valid?
    end
  end

  describe "add_source_query_param/1" do
    test "given an existing dataset with no params, it adds a new, blank param to it", %{org_id: org_id} do
      dataset = TDG.create_dataset(%{organization_id: org_id, technical: %{sourceQueryParams: %{}}})

      {:ok, %{technical: %{sourceQueryParams: []}} = _andi_dataset} = Datasets.update(dataset)

      assert {:ok, %{technical: %{sourceQueryParams: [%{id: _, key: nil, value: nil}]}}} = Datasets.add_source_query_param(dataset.id)
    end

    test "given an existing dataset, it adds a new, blank param to it", %{org_id: org_id} do
      dataset = TDG.create_dataset(%{organization_id: org_id, technical: %{sourceQueryParams: %{"foo" => "baz"}}})

      {:ok, %{technical: %{sourceQueryParams: [%{id: original_id, key: "foo", value: "baz"}]}} = _andi_dataset} = Datasets.update(dataset)

      assert {:ok, %{technical: %{sourceQueryParams: [%{id: ^original_id}, %{id: _, key: nil, value: nil}]}}} =
               Datasets.add_source_query_param(dataset.id)
    end
  end

  describe "add_source_header/1" do
    test "given an existing dataset with no headers, it adds a new, blank source header to it", %{org_id: org_id} do
      dataset = TDG.create_dataset(%{organization_id: org_id, technical: %{sourceHeaders: %{}}})

      {:ok, %{technical: %{sourceHeaders: []}} = _andi_dataset} = Datasets.update(dataset)

      assert {:ok, %{technical: %{sourceHeaders: [%{id: _, key: nil, value: nil}]}}} = Datasets.add_source_header(dataset.id)
    end

    test "given an existing dataset, it adds a new, blank source header to it", %{org_id: org_id} do
      dataset = TDG.create_dataset(%{organization_id: org_id, technical: %{sourceHeaders: %{"api-key" => "to-my-heart"}}})

      {:ok, %{technical: %{sourceHeaders: [%{id: original_id, key: "api-key", value: "to-my-heart"}]}} = _andi_dataset} =
        Datasets.update(dataset)

      assert {:ok, %{technical: %{sourceHeaders: [%{id: ^original_id}, %{id: _, key: nil, value: nil}]}}} =
               Datasets.add_source_header(dataset.id)
    end
  end

  describe "get_all/0" do
    test "given existing datasets, it returns them, with at least business and technical preloaded", %{org_id: org_id} do
      dataset_one = TDG.create_dataset(%{organization_id: org_id})
      dataset_two = TDG.create_dataset(%{organization_id: org_id})

      assert {:ok, _} = Datasets.update(dataset_one)
      assert {:ok, _} = Datasets.update(dataset_two)

      assert [%{business: %{id: _bid}, technical: %{id: _tid}} | _] = Datasets.get_all()
    end
  end

  describe "get/1" do
    test "given an existing dataset, it returns it, preloaded", %{org_id: org_id} do
      dataset = TDG.create_dataset(%{organization_id: org_id})

      {:ok, %{id: dataset_id, business: %{id: business_id}, technical: %{id: technical_id, schema: [%{id: schema_id} | _]}} = _andi_dataset} =
        Datasets.update(dataset)

      assert %{id: ^dataset_id, business: %{id: ^business_id}, technical: %{id: ^technical_id, schema: [%{id: ^schema_id} | _]}} =
               Datasets.get(dataset.id)
    end

    test "given a non-existing dataset, it returns nil" do
      assert nil == Datasets.get("not_there")
    end
  end

  describe "delete/1" do
    test "given an existing dataset, it cascade deletes it", %{org_id: org_id} do
      dataset = TDG.create_dataset(%{organization_id: org_id})

      {:ok, %{business: %{id: business_id}, technical: %{id: technical_id, schema: [%{id: schema_id} | _]}} = _andi_dataset} =
        Datasets.update(dataset)

      assert {:ok, _} = Datasets.delete(dataset.id)
      assert nil == Andi.Repo.get(Business, business_id)
      assert nil == Andi.Repo.get(Technical, technical_id)
      assert nil == Andi.Repo.get(DataDictionary, schema_id)
    end
  end

  describe "update_ingested_time/2" do
    test "given an existing dataset, it adds the ingested time into it", %{org_id: org_id} do
      dataset = TDG.create_dataset(%{organization_id: org_id})

      {:ok, _andi_dataset} = Datasets.update(dataset)

      now = DateTime.utc_now()

      assert {:ok, %{ingestedTime: ingested_time_from_db} = andi_dataset} = Datasets.update_ingested_time(dataset.id, now)

      assert DateTime.diff(ingested_time_from_db, now) == 0
    end

    test "given a non-existing dataset, it creates a partial one to be filled later", %{org_id: org_id} do
      dataset = TDG.create_dataset(%{organization_id: org_id})

      now = DateTime.utc_now()

      assert {:ok, %{ingestedTime: ingested_time_from_db} = andi_dataset} = Datasets.update_ingested_time(dataset.id, now)

      assert DateTime.diff(ingested_time_from_db, now) == 0
    end
  end

  describe "update/1" do
    test "given a newly seen smart city dataset, turns it into an Andi dataset", %{org_id: org_id} do
      dataset = TDG.create_dataset(%{organization_id: org_id})

      assert {:ok, _} = Datasets.update(dataset)
    end

    test "given an existing smart city dataset, updates it", %{org_id: org_id} do
      dataset = TDG.create_dataset(%{organization_id: org_id})

      original_data_title = dataset.business.dataTitle

      assert {:ok, %Andi.InputSchemas.Datasets.Dataset{business: %{dataTitle: ^original_data_title}} = andi_dataset} =
               Datasets.update(dataset)

      original_business_id = andi_dataset.business.id
      original_technical_id = andi_dataset.technical.id

      updated_dataset = put_in(dataset, [:business, :dataTitle], "something different")

      assert {:ok,
              %Andi.InputSchemas.Datasets.Dataset{
                business: %{
                  id: ^original_business_id,
                  dataTitle: "something different"
                },
                technical: %{
                  id: ^original_technical_id
                }
              }} = Datasets.update(updated_dataset)
    end

    test "given a blank extract step body, retains it", %{org_id: org_id} do
      smrt_dataset =
        TDG.create_dataset(%{
          organization_id: org_id,
          technical: %{
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
          }
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)
      step = dataset.technical.extractSteps |> Enum.at(0)
      assert step.context.body == ""
    end
  end

  describe "full_validation_changeset/1" do
    test "requires unique orgName and dataName", %{org_id: org_id} do
      existing_dataset = TDG.create_dataset(%{organization_id: org_id, technical: %{sourceType: "remote"}})
      {:ok, _} = Datasets.update(existing_dataset)

      changeset =
        existing_dataset
        |> StructTools.to_map()
        |> Map.put(:id, UUID.uuid4())
        |> InputConverter.smrt_dataset_to_full_changeset()

      technical_changeset = Ecto.Changeset.get_change(changeset, :technical)

      refute changeset.valid?
      assert technical_changeset.errors == [{:dataName, {"existing dataset has the same orgName and dataName", []}}]
    end

    test "allows same orgName and dataName when id is same", %{org_id: org_id} do
      existing_dataset = TDG.create_dataset(%{organization_id: org_id, technical: %{sourceType: "remote"}})
      {:ok, _} = Datasets.update(existing_dataset)

      changeset = InputConverter.smrt_dataset_to_full_changeset(existing_dataset)

      assert changeset.valid?
      assert changeset.errors == []
    end

    test "includes light validation", %{org_id: org_id} do
      dataset = TDG.create_dataset(%{organization_id: org_id})
      {:ok, _} = Datasets.update(dataset)

      changeset =
        dataset
        |> StructTools.to_map()
        |> put_in([:business, :contactEmail], "nope")
        |> delete_in([:technical, :sourceFormat])
        |> InputConverter.smrt_dataset_to_full_changeset()

      refute changeset.valid?
    end
  end

  defp delete_in(data, path) do
    pop_in(data, path) |> elem(1)
  end
end
