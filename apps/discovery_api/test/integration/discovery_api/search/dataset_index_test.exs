defmodule DiscoveryApi.Data.Search.DatasetIndexTest do
  use ExUnit.Case
  use Divo, services: [:redis, :"ecto-postgres", :zookeeper, :kafka, :elasticsearch]
  use DiscoveryApi.ElasticSearchCase

  import SmartCity.TestHelper, only: [eventually: 1]

  alias DiscoveryApi.Test.Helper
  alias SmartCity.TestDataGenerator, as: TDG

  alias DiscoveryApi.Search.DatasetIndex, as: DatasetSearchIndex
  alias DiscoveryApi.Data.Model

  describe "create_index/0" do
    test "it creates the datasets index", %{es_indices: %{datasets: index}} do
      assert {:ok, _} = DatasetSearchIndex.delete_index()
      assert {:ok, created} = DatasetSearchIndex.create_index()

      index_name_as_atom = String.to_atom(index.name)
      assert created[index_name_as_atom][:mappings] != %{}
    end
  end

  describe "delete_index/0" do
    test "it deletes the datasets index" do
      assert {:ok, _} = DatasetSearchIndex.delete_index()
      assert {:error, _} = DatasetSearchIndex.get_index()
    end
  end

  describe "get_index/0" do
    test "it gets the datasets index", %{es_indices: %{datasets: index}} do
      assert {:ok, gotten} = DatasetSearchIndex.get_index()

      index_name_as_atom = String.to_atom(index.name)
      assert gotten[index_name_as_atom][:mappings] != %{}
    end
  end

  describe "delete/1" do
    test "removes dataset from index" do
      dataset = index_model(%{description: "Sensor Data"})

      {:ok, _response} = DatasetSearchIndex.delete(dataset.id)

      eventually(fn ->
        {:ok, models, _facets} = DatasetSearchIndex.search(query: "Sensor Data")
        assert 0 == length(models)
      end)
    end
  end

  describe "reset_index/0" do
    test "it resets the datasets index", %{es_indices: %{datasets: index}} do
      assert {:ok, reset} = DatasetSearchIndex.reset_index()

      index_name_as_atom = String.to_atom(index.name)
      assert reset[index_name_as_atom][:mappings] != %{}
    end
  end

  describe "create_index/2" do
    test "given an index name with no options, it creates it" do
      name =
        Faker.Name.first_name()
        |> String.downcase()

      on_exit(fn ->
        DatasetSearchIndex.delete_index(name)
      end)

      assert {:ok, _} = DatasetSearchIndex.create_index(name)
    end

    test "given an invalid index name (must be lowercase) it returns an error" do
      name =
        Faker.Name.first_name()
        |> String.upcase()

      assert {:error, _} = DatasetSearchIndex.create_index(name)
    end

    test "given an index name with some options (mapping) it creates it" do
      name =
        Faker.Name.first_name()
        |> String.downcase()

      name_as_atom = String.to_atom(name)

      options = %{
        mappings: %{
          properties: %{
            title: %{
              type: "keyword",
              index: false
            }
          }
        }
      }

      on_exit(fn ->
        DatasetSearchIndex.delete_index(name)
      end)

      assert {:ok, _} = DatasetSearchIndex.create_index(name, options)
      assert {:ok, index} = DatasetSearchIndex.get_index(name)

      assert options.mappings == index[name_as_atom][:mappings]
    end
  end

  describe "delete_index/1" do
    test "given an index that does not exist, it does not error" do
      name =
        Faker.Name.first_name()
        |> String.downcase()

      assert {:ok, _} = DatasetSearchIndex.delete_index(name)
    end

    test "given an index that does exist, it does delete the index" do
      name =
        Faker.Name.first_name()
        |> String.downcase()

      assert {:ok, _} = DatasetSearchIndex.create_index(name)
      assert {:ok, _} = DatasetSearchIndex.delete_index(name)

      assert {:error, error} = DatasetSearchIndex.get_index(name)

      assert %{type: "index_not_found_exception"} = error
    end

    test "given a failure to delete for some other reason, it returns the error" do
      bypass = Bypass.open()
      reconfigure_es_url("http://localhost:#{bypass.port}")

      name =
        Faker.Name.first_name()
        |> String.downcase()

      Bypass.stub(bypass, "DELETE", "/#{name}", fn conn ->
        Plug.Conn.resp(conn, 500, ~s({"error": "darsh was here"}))
      end)

      assert {:error, _} = DatasetSearchIndex.delete_index(name)
    end
  end

  describe "reset_index/1" do
    test "given an index that does not exist, it builds it" do
      name =
        Faker.Name.first_name()
        |> String.downcase()

      name_as_atom = String.to_atom(name)

      options = %{
        mappings: %{
          properties: %{
            title: %{
              type: "keyword",
              index: false
            }
          }
        }
      }

      on_exit(fn ->
        DatasetSearchIndex.delete_index(name)
      end)

      assert {:ok, _} = DatasetSearchIndex.reset_index(name, options)
      assert {:ok, index} = DatasetSearchIndex.get_index(name)
      assert options.mappings == index[name_as_atom][:mappings]
    end

    test "given an index that exists, it replaces it" do
      name =
        Faker.Name.first_name()
        |> String.downcase()

      name_as_atom = String.to_atom(name)

      existing_options = %{
        mappings: %{
          properties: %{
            title: %{
              type: "keyword",
              index: false
            }
          }
        }
      }

      on_exit(fn ->
        DatasetSearchIndex.delete_index(name)
      end)

      assert {:ok, _} = DatasetSearchIndex.create_index(name, existing_options)
      assert {:ok, existing_index} = DatasetSearchIndex.get_index(name)
      assert existing_options.mappings == existing_index[name_as_atom][:mappings]

      new_options = %{
        mappings: %{
          properties: %{
            name: %{
              type: "keyword",
              index: false
            }
          }
        }
      }

      assert {:ok, _} = DatasetSearchIndex.reset_index(name, new_options)
      assert {:ok, replaced_index} = DatasetSearchIndex.get_index(name)
      assert new_options.mappings == replaced_index[name_as_atom][:mappings]
    end

    test "given a failure to delete for some reason, it returns the error" do
      bypass = Bypass.open()
      reconfigure_es_url("http://localhost:#{bypass.port}")

      name =
        Faker.Name.first_name()
        |> String.downcase()

      Bypass.stub(bypass, "DELETE", "/#{name}", fn conn ->
        Plug.Conn.resp(conn, 500, ~s({"error": "yep"}))
      end)

      assert {:error, _} = DatasetSearchIndex.reset_index(name, %{})
    end

    test "given a failure to create for some reason, it returns the error" do
      bypass = Bypass.open()
      reconfigure_es_url("http://localhost:#{bypass.port}")

      name =
        Faker.Name.first_name()
        |> String.downcase()

      Bypass.stub(bypass, "DELETE", "/#{name}", fn conn ->
        Plug.Conn.resp(conn, 200, "")
      end)

      Bypass.stub(bypass, "PUT", "/#{name}", fn conn ->
        Plug.Conn.resp(conn, 500, ~s({"error": "that's no good"}))
      end)

      assert {:error, _} = DatasetSearchIndex.reset_index(name, %{})
    end
  end

  describe "get/1" do
    test "given an existing dataset, it returns it" do
      dataset = Helper.sample_model()
      atomized_dataset = expected_dataset(dataset)
      assert {:ok, _saved} = DatasetSearchIndex.update(dataset)

      assert {:ok, gotten} = DatasetSearchIndex.get(dataset.id)
      assert atomized_dataset == gotten
    end

    test "given a missing dataset, it returns an error" do
      dataset = Helper.sample_model()

      assert {:error, _} = DatasetSearchIndex.get(dataset.id)
    end
  end

  describe "get_all/0" do
    test "given multiple existing datasets, it returns them" do
      dataset_one = Helper.sample_model()
      dataset_two = Helper.sample_model()

      atomized_dataset_one = expected_dataset(dataset_one)
      atomized_dataset_two = expected_dataset(dataset_two)
      atomized_datasets = [atomized_dataset_one, atomized_dataset_two]

      assert {:ok, _saved} = DatasetSearchIndex.update(dataset_one)
      assert {:ok, _saved} = DatasetSearchIndex.update(dataset_two)

      assert {:ok, atomized_datasets} == DatasetSearchIndex.get_all()
    end

    test "given no existing datasets, it returns an empty list" do
      assert {:ok, []} == DatasetSearchIndex.get_all()
    end

    test "given a search failure it returns an error", %{es_indices: %{datasets: %{name: datasets}}} do
      bypass = Bypass.open()
      reconfigure_es_url("http://localhost:#{bypass.port}")

      Bypass.stub(bypass, "POST", "/#{datasets}/_doc/_search", fn conn ->
        Plug.Conn.resp(conn, 400, ~s({"error": "you think you can beat me?!"}))
      end)

      assert {:error, _} = DatasetSearchIndex.get_all()
    end
  end

  describe "update/1" do
    test "given a new dataset, it creates it in elasticsearch" do
      dataset = Helper.sample_model()
      atomized_dataset = expected_dataset(dataset)

      assert {:ok, _} = DatasetSearchIndex.update(dataset)
      assert {:ok, saved} = DatasetSearchIndex.get(dataset.id)
      assert atomized_dataset == saved
    end

    test "given an existing dataset, it merges the changes in elasticsearch" do
      existing_dataset = Helper.sample_model()
      assert {:ok, _saved} = DatasetSearchIndex.update(existing_dataset)

      original_title = existing_dataset.title
      updated_name = "Look at me, I'm a new name!"
      partial_update = %Model{id: existing_dataset.id, name: updated_name}

      assert {:ok, _} = DatasetSearchIndex.update(partial_update)
      assert {:ok, updated} = DatasetSearchIndex.get(partial_update.id)

      assert %Model{title: ^original_title, name: ^updated_name} = updated
    end

    test "the dataset it updates is immediately searchable (refresh = true)" do
      dataset = Helper.sample_model()
      atomized_dataset = expected_dataset(dataset)

      assert {:ok, _saved} = DatasetSearchIndex.update(dataset)

      assert {:ok, [atomized_dataset]} == DatasetSearchIndex.get_all()
    end

    test "given a dataset with no id, it returns an error" do
      dataset =
        Helper.sample_model()
        |> Map.delete(:id)

      assert {:error, _reason} = DatasetSearchIndex.update(dataset)
    end

    test "given a missing dataset index, it returns an error", %{es_indices: %{datasets: %{name: datasets}}} do
      delete_es_index(datasets)

      dataset = Helper.sample_model()

      assert {:error, _reason} = DatasetSearchIndex.update(dataset)
    end

    test "given an error from ES, it returns the error", %{es_indices: %{datasets: %{name: datasets}}} do
      dataset = Helper.sample_model()

      bypass = Bypass.open()
      reconfigure_es_url("http://localhost:#{bypass.port}")

      Bypass.stub(bypass, "HEAD", "/#{datasets}", fn conn ->
        Plug.Conn.resp(conn, 200, "")
      end)

      stub_path = "/#{datasets}/_doc/#{dataset.id}/_update"

      Bypass.stub(bypass, "POST", stub_path, fn conn ->
        Plug.Conn.resp(conn, 400, ~s({"error": "something bad happened"}))
      end)

      assert {:error, _reason} = DatasetSearchIndex.update(dataset)
    end
  end

  describe "replace/1" do
    test "given a new dataset, it creates it in elasticsearch" do
      dataset = Helper.sample_model()
      atomized_dataset = expected_dataset(dataset)

      assert {:ok, _} = DatasetSearchIndex.replace(dataset)
      assert {:ok, saved} = DatasetSearchIndex.get(dataset.id)
      assert atomized_dataset == saved
    end

    test "given an existing dataset, it merges the changes in elasticsearch" do
      existing_dataset = Helper.sample_model()
      assert {:ok, _saved} = DatasetSearchIndex.replace(existing_dataset)

      existing_id = existing_dataset.id
      updated_name = "Look at me, I'm a new name!"
      partial_update = %Model{id: existing_id, name: updated_name}

      assert {:ok, _} = DatasetSearchIndex.replace(partial_update)
      assert {:ok, replaced} = DatasetSearchIndex.get(partial_update.id)

      assert %Model{id: existing_id, name: updated_name} == replaced
    end

    test "the dataset it replaces is immediately searchable (refresh = true)" do
      dataset = Helper.sample_model()
      atomized_dataset = expected_dataset(dataset)

      assert {:ok, _saved} = DatasetSearchIndex.replace(dataset)

      assert {:ok, [atomized_dataset]} == DatasetSearchIndex.get_all()
    end

    test "given a dataset with no id, it returns an error" do
      dataset =
        Helper.sample_model()
        |> Map.delete(:id)

      assert {:error, _reason} = DatasetSearchIndex.replace(dataset)
    end

    test "given a missing dataset index, it returns an error", %{es_indices: %{datasets: %{name: datasets}}} do
      delete_es_index(datasets)

      dataset = Helper.sample_model()

      assert {:error, _reason} = DatasetSearchIndex.replace(dataset)
    end

    test "given an error returned from ES, it returns an error", %{es_indices: %{datasets: %{name: datasets}}} do
      dataset = Helper.sample_model()

      bypass = Bypass.open()
      reconfigure_es_url("http://localhost:#{bypass.port}")

      Bypass.stub(bypass, "HEAD", "/#{datasets}", fn conn ->
        Plug.Conn.resp(conn, 200, "")
      end)

      stub_path = "/#{datasets}/_doc/#{dataset.id}/"

      Bypass.stub(bypass, "PUT", stub_path, fn conn ->
        Plug.Conn.resp(conn, 400, ~s({"error": "something bad happened"}))
      end)

      assert {:error, _reason} = DatasetSearchIndex.replace(dataset)
    end
  end

  describe "replace_all/1" do
    test "given non-existing datasets index, it puts all datasets in the index", %{es_indices: %{datasets: %{name: datasets}}} do
      delete_es_index(datasets)

      dataset_one = Helper.sample_model()
      dataset_two = Helper.sample_model()
      datasets = [dataset_one, dataset_two]

      atomized_dataset_one = expected_dataset(dataset_one)
      atomized_dataset_two = expected_dataset(dataset_two)
      atomized_datasets = [atomized_dataset_one, atomized_dataset_two]

      assert {:ok, _} = DatasetSearchIndex.replace_all(datasets)
      assert {:ok, saved} = DatasetSearchIndex.get_all()
      assert atomized_datasets == saved
    end

    test "given an existing index, it puts all datasets in the index, destroying anything that was there already" do
      existing_dataset = Helper.sample_model()
      assert {:ok, _updated} = DatasetSearchIndex.update(existing_dataset)

      dataset_one = Helper.sample_model()
      dataset_two = Helper.sample_model()
      datasets = [dataset_one, dataset_two]

      atomized_dataset_one = expected_dataset(dataset_one)
      atomized_dataset_two = expected_dataset(dataset_two)
      atomized_datasets = [atomized_dataset_one, atomized_dataset_two]

      assert {:ok, _} = DatasetSearchIndex.replace_all(datasets)
      assert {:ok, saved} = DatasetSearchIndex.get_all()
      assert atomized_datasets == saved
    end

    test "if it fails to delete the index before replacing, it returns an error", %{es_indices: %{datasets: %{name: datasets}}} do
      bypass = Bypass.open()
      reconfigure_es_url("http://localhost:#{bypass.port}")

      Bypass.stub(bypass, "DELETE", "/#{datasets}", fn conn ->
        Plug.Conn.resp(conn, 500, ~s({"error": "something bad happened"}))
      end)

      datasets = [Helper.sample_model(), Helper.sample_model()]
      assert {:error, _} = DatasetSearchIndex.replace_all(datasets)
    end

    test "if it fails to create the index before replacing, it returns an error", %{es_indices: %{datasets: %{name: datasets}}} do
      bypass = Bypass.open()
      reconfigure_es_url("http://localhost:#{bypass.port}")

      Bypass.stub(bypass, "DELETE", "/#{datasets}", fn conn ->
        Plug.Conn.resp(conn, 200, "")
      end)

      Bypass.stub(bypass, "PUT", "/#{datasets}", fn conn ->
        Plug.Conn.resp(conn, 500, ~s({"error": "something even worse happened"}))
      end)

      datasets = [Helper.sample_model(), Helper.sample_model()]
      assert {:error, _} = DatasetSearchIndex.replace_all(datasets)
    end

    test "if it fails while bulk putting the datasets, it retuns an error", %{es_indices: %{datasets: %{name: datasets}}} do
      bypass = Bypass.open()
      reconfigure_es_url("http://localhost:#{bypass.port}")

      Bypass.stub(bypass, "DELETE", "/#{datasets}", fn conn ->
        Plug.Conn.resp(conn, 200, "")
      end)

      Bypass.stub(bypass, "PUT", "/#{datasets}", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"good": "things"}))
      end)

      Bypass.stub(bypass, "GET", "/#{datasets}", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"good": "things"}))
      end)

      Bypass.stub(bypass, "PUT", "/_bulk", fn conn ->
        Plug.Conn.resp(conn, 500, ~s({"error": "YOU. LOSE."}))
      end)

      datasets = [Helper.sample_model(), Helper.sample_model()]
      assert {:error, _} = DatasetSearchIndex.replace_all(datasets)
    end
  end

  describe "search/?" do
    test "given a dataset with a matching search term" do
      dataset_one = index_model(%{title: "Nazderaldac"})
      index_model()

      {:ok, models, _facets} = DatasetSearchIndex.search(query: "Nazderaldac")
      assert [dataset_one] == models
    end

    test "should not return private datasets when user is unauthenticated" do
      index_model(%{description: "Accio Dataset!", private: true})
      dataset_two = index_model(%{description: "Accio Dataset!", private: false})

      {:ok, models, _facets} = DatasetSearchIndex.search(query: "Accio Dataset")

      assert [dataset_two] == models
    end

    test "should return private datasets for the authenticated users's associated organization" do
      _private_unauthorized = index_model(%{id: "1", description: "Parking Transactions", private: true, organizationDetails: %{id: "o3"}})
      public = index_model(%{id: "2", description: "Parking Transactions", private: false})
      private_org_1 = index_model(%{id: "3", description: "Parking Transactions", private: true, organizationDetails: %{id: "o1"}})
      private_org_2 = index_model(%{id: "4", description: "Parking Transactions", private: true, organizationDetails: %{id: "o2"}})

      {:ok, models, _facets} = DatasetSearchIndex.search(query: "Parking Transactions", authorized_organization_ids: ["o1", "o2"])

      extract_id_and_sort = &(Enum.map(&1, fn model -> model.id end) |> Enum.sort())
      expected_dataset_ids = extract_id_and_sort.([public, private_org_1, private_org_2])
      actual_dataset_ids = extract_id_and_sort.(models)
      assert expected_dataset_ids == actual_dataset_ids
    end

    test "given a dataset that is private when user has access" do
      index_model(%{description: "Accio Dataset!", private: true})
      dataset_two = index_model(%{description: "Accio Dataset!", private: false})

      {:ok, models, _facets} = DatasetSearchIndex.search(query: "Accio Dataset")
      assert [dataset_two] == models
    end

    test "given a dataset with an org in a search term" do
      organization_1_name = "Olivanders Emporium"
      organization_1 = TDG.create_organization(%{orgTitle: organization_1_name}) |> Map.from_struct()
      dataset_one = index_model(%{organizationDetails: organization_1})
      index_model()

      {:ok, models, _facets} = DatasetSearchIndex.search(query: "Olivanders")
      assert [dataset_one] == models
    end

    test "given a dataset with a keyword in a search term" do
      dataset_one = index_model(%{keywords: ["Newts", "Scales", "Tails"]})
      index_model()

      {:ok, models, _facets} = DatasetSearchIndex.search(query: "Newts")
      assert [dataset_one] == models
    end

    test "given multiple datasets with the same search term" do
      index_model(%{title: "Ingredients", keywords: ["Newt", "Scale", "Tail"]})
      index_model(%{title: "Reports", description: "Newt Scamander's reports 1920-1930"})
      index_model(%{title: "Others"})

      {:ok, models, _facets} = DatasetSearchIndex.search(query: "Newt")
      assert 2 == length(models)
      assert Enum.any?(models, fn model -> model.title == "Reports" end)
      assert Enum.any?(models, fn model -> model.title == "Ingredients" end)
      refute Enum.any?(models, fn model -> model.title == "Others" end)
    end

    test "given multiple datasets covered by multiple search terms" do
      index_model(%{title: "Library Records"})
      index_model(%{title: "Class Reports", keywords: ["Records"]})
      index_model(%{title: "Room Inventory", keywords: ["Library"]})
      index_model(%{title: "Others"})

      {:ok, models, _facets} = DatasetSearchIndex.search(query: "Library Records")
      assert 3 == length(models)
      assert Enum.any?(models, fn model -> model.title == "Library Records" end)
      assert Enum.any?(models, fn model -> model.title == "Class Reports" end)
      assert Enum.any?(models, fn model -> model.title == "Room Inventory" end)
      refute Enum.any?(models, fn model -> model.title == "Others" end)
    end

    test "given no datasets with the search term" do
      index_model()
      index_model()

      {:ok, models, _facets} = DatasetSearchIndex.search(query: "Hippogriff")
      assert [] == models
    end

    test "given datasets but no search term" do
      index_model(%{title: "Student Roster"})
      index_model(%{title: "Inventory"})

      {:ok, models, _facets} = DatasetSearchIndex.search(query: "")
      assert 2 == length(models)
      assert Enum.any?(models, fn model -> model.title == "Student Roster" end)
      assert Enum.any?(models, fn model -> model.title == "Inventory" end)
    end

    test "given a dataset with a matching keyword" do
      index_model(%{title: "Room List (West Wing)", keywords: ["inventory"]})
      index_model(%{title: "Passageways -- GEOJSON"})

      {:ok, models, _facets} = DatasetSearchIndex.search(keywords: ["inventory"])
      assert 1 == length(models)
      assert Enum.any?(models, fn model -> model.title == "Room List (West Wing)" end)
    end

    test "given a dataset with all matching keywords" do
      index_model(%{title: "Room List (East Wing)", keywords: ["inventory"]})
      index_model(%{title: "Ingredient List", keywords: ["inventory", "magic"]})
      index_model(%{title: "Passageways (Dungeon) -- GEOJSON", keywords: ["magic"]})
      index_model(%{title: "Ingredient List (Restricted)", keywords: ["inventory", "magic", "test"]})

      {:ok, models, _facets} = DatasetSearchIndex.search(keywords: ["inventory", "magic"])
      assert 2 == length(models)
      assert Enum.any?(models, fn model -> model.title == "Ingredient List" end)
      assert Enum.any?(models, fn model -> model.title == "Ingredient List (Restricted)" end)
    end

    test "given no datasets with matching keywords" do
      index_model(%{title: "Room List (North Wing)", keywords: ["inventory"]})
      index_model(%{title: "Ingredient List", keywords: ["inventory", "magic"]})
      index_model(%{title: "Passageways (Faculty Level) -- GEOJSON", keywords: ["magic"]})

      {:ok, models, _facets} = DatasetSearchIndex.search(keywords: ["goblin", "gnome"])
      assert [] == models
    end

    test "given a dataset with a matching organization" do
      organization = TDG.create_organization(%{orgTitle: "School"}) |> Map.from_struct()
      dataset_one = index_model(%{organizationDetails: organization})
      index_model()

      {:ok, models, _facets} = DatasetSearchIndex.search(org_title: organization.orgTitle)
      assert dataset_one == List.first(models)
    end

    test "given no datasets with matching organization" do
      index_model()
      index_model()

      {:ok, models, _facets} = DatasetSearchIndex.search(org_title: "Orthagan Alley Inc.")
      assert [] == models
    end

    test "given a dataset that is api accessible" do
      index_model(%{title: "Mail Status", sourceType: "stream"})
      index_model(%{title: "Owl Registry", sourceType: "ingest"})
      index_model(%{title: "Hallways -- GEOJSON", sourceType: "host"})

      {:ok, models, _facets} = DatasetSearchIndex.search(api_accessible: true)
      assert 2 == length(models)
      assert Enum.any?(models, fn model -> model.title == "Mail Status" end)
      assert Enum.any?(models, fn model -> model.title == "Owl Registry" end)
    end

    test "given datasets that have keywords" do
      index_model(%{title: "Form 1 Student List", keywords: ["students", "forms"]})
      index_model(%{title: "House Prefects", keywords: ["students", "houses"]})

      {:ok, _models, %{keywords: keyword_facets}} = DatasetSearchIndex.search()
      assert 3 == length(keyword_facets)
      assert [%{name: "students", count: 2}, %{name: "forms", count: 1}, %{name: "houses", count: 1}] == keyword_facets
    end

    test "given datasets that have organizations" do
      organization1 = TDG.create_organization(%{orgTitle: "Faculty"}) |> Map.from_struct()
      organization2 = TDG.create_organization(%{orgTitle: "Headmaster's Office"}) |> Map.from_struct()
      index_model(%{title: "Form 2 Student List", organizationDetails: organization1})
      index_model(%{title: "House Leaders", organizationDetails: organization1})
      index_model(%{title: "Headmaster's List", organizationDetails: organization2})

      {:ok, _models, %{organization: org_facets}} = DatasetSearchIndex.search()
      assert 2 == length(org_facets)
      assert [%{name: "Faculty", count: 2}, %{name: "Headmaster's Office", count: 1}] == org_facets
    end
  end

  defp reconfigure_es_url(url) do
    original_config = Application.get_env(:discovery_api, :elasticsearch)
    updated_config = Keyword.put(original_config, :url, url)

    Application.put_env(:discovery_api, :elasticsearch, updated_config)

    on_exit(fn ->
      Application.put_env(:discovery_api, :elasticsearch, original_config)
    end)
  end

  defp expected_dataset(dataset) do
    map =
      dataset
      |> Map.from_struct()
      |> AtomicMap.convert(safe: false, underscore: false)
      |> Map.delete(:completeness)

    struct(Model, map)
  end

  defp index_model(overrides \\ %{}) do
    dataset = Helper.sample_model(overrides)

    assert {:ok, _saved} = DatasetSearchIndex.update(dataset)

    expected_dataset(dataset)
  end
end
