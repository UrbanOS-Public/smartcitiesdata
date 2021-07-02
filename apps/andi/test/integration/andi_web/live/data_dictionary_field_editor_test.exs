defmodule AndiWeb.EditLiveView.DataDictionaryFieldEditorTest do
  use ExUnit.Case
  use AndiWeb.Test.PublicAccessCase
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  import Phoenix.LiveViewTest
  import Checkov

  @moduletag shared_data_connection: true

  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Organizations
  alias Andi.InputSchemas.Datasets.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  import FlokiHelpers,
    only: [
      find_elements: 2,
      get_value: 2,
      get_select: 2,
      get_select_first_option: 2,
      get_all_select_options: 2,
      get_attributes: 3
    ]

  @url_path "/submissions/"

  setup do
    smrt_org = TDG.create_organization(%{})
    Organizations.update(smrt_org)
    [org_id: smrt_org.id]
  end

  test "type-info input is not displayed when type is neither list, date, nor timestamp", %{conn: conn, org_id: org_id} do
    smrt_dataset = TDG.create_dataset(%{organization_id: org_id, technical: %{schema: [%{name: "one", type: "string"}]}})

    {:ok, dataset} = Datasets.update(smrt_dataset)

    {:ok, _view, html} = live(conn, @url_path <> dataset.id)

    assert Enum.empty?(find_elements(html, ".data-dictionary-field-editor__item-type"))
    assert Enum.empty?(find_elements(html, ".data-dictionary-field-editor__format"))
  end

  test "item type selector is shown when field type is a list", %{conn: conn, org_id: org_id} do
    field_id = UUID.uuid4()

    smrt_dataset =
      TDG.create_dataset(%{organization_id: org_id, technical: %{schema: [%{id: field_id, name: "one", itemType: "string", type: "list"}]}})

    {:ok, dataset} = Datasets.update(smrt_dataset)

    {:ok, _, html} = live(conn, @url_path <> dataset.id)

    refute Enum.empty?(find_elements(html, ".data-dictionary-field-editor__item-type"))
  end

  test "item type selector does not allow list of lists", %{conn: conn, org_id: org_id} do
    field_id = UUID.uuid4()

    smrt_dataset =
      TDG.create_dataset(%{organization_id: org_id, technical: %{schema: [%{id: field_id, name: "one", itemType: "list", type: "list"}]}})

    {:ok, dataset} = Datasets.update(smrt_dataset)

    {:ok, _, html} = live(conn, @url_path <> dataset.id)

    refute Enum.empty?(find_elements(html, "#itemType-error-msg"))
    assert {"List", "list"} not in get_all_select_options(html, ".data-dictionary-field-editor__item-type")
  end

  data_test "format input is shown when field type is #{field}", %{conn: conn, org_id: org_id} do
    field_id = UUID.uuid4()

    smrt_dataset =
      TDG.create_dataset(%{
        organization_id: org_id,
        technical: %{schema: [%{id: field_id, name: "one", type: field, format: "{ISO:Extended}"}]}
      })

    {:ok, dataset} = Datasets.update(smrt_dataset)

    {:ok, _, html} = live(conn, @url_path <> dataset.id)

    refute Enum.empty?(find_elements(html, ".data-dictionary-field-editor__format"))

    where(field: ["date", "timestamp"])
  end

  data_test "empty values for #{selector_name} are selected by default", %{conn: conn, org_id: org_id} do
    smrt_dataset = TDG.create_dataset(%{organization_id: org_id, technical: %{schema: [], sourceType: "remote"}})

    {:ok, dataset} = Datasets.update(smrt_dataset)

    {:ok, _view, html} = live(conn, @url_path <> dataset.id)

    case field_type do
      "select" ->
        assert get_select(html, ".data-dictionary-field-editor__#{selector_name}") == []
        assert get_select_first_option(html, ".data-dictionary-field-editor__#{selector_name}") == {"", []}

      "text" ->
        assert get_value(html, ".data-dictionary-field-editor__#{selector_name}") == nil
    end

    where([
      [:selector_name, :field_type],
      ["name", "text"],
      ["type", "select"],
      ["description", "text"],
      ["pii", "select"],
      ["masked", "select"],
      ["demographic", "select"],
      ["biased", "select"],
      ["rationale", "text"]
    ])
  end

  test "xml selector is disabled when source type is not xml", %{conn: conn, org_id: org_id} do
    smrt_dataset = TDG.create_dataset(%{organization_id: org_id, technical: %{sourceFormat: "text/csv"}})
    {:ok, dataset} = Datasets.update(smrt_dataset)

    {:ok, _view, html} = live(conn, @url_path <> dataset.id)

    refute Enum.empty?(get_attributes(html, ".data-dictionary-field-editor__selector", "disabled"))
  end

  test "xml selector is enabled when source type is xml", %{conn: conn, org_id: org_id} do
    smrt_dataset = TDG.create_dataset(%{organization_id: org_id, technical: %{sourceFormat: "text/xml"}})

    {:ok, dataset} =
      InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
      |> Datasets.save()

    {:ok, _view, html} = live(conn, @url_path <> dataset.id)

    assert Enum.empty?(get_attributes(html, ".data-dictionary-field-editor__selector", "disabled"))
  end

  describe "validation" do
    data_test "missing #{field} shows error", %{conn: conn, org_id: org_id} do
      schema =
        [%{name: "cam", type: "list", item_type: "string", selector: "cam/cam"}]
        |> remove_field_from_schema(field)

      smrt_dataset = TDG.create_dataset(%{organization_id: org_id, technical: %{sourceFormat: "text/xml", schema: schema}})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      refute Enum.empty?(find_elements(html, ".data-dictionary-field-editor__#{class} > .error-msg"))

      where(
        field: [:name, :type, :item_type, :selector],
        class: ["name", "type", "type-info", "selector"]
      )
    end

    test "dataset with no schema does not perform field editor validation", %{conn: conn, org_id: org_id} do
      smrt_dataset = TDG.create_dataset(%{organization_id: org_id, technical: %{schema: []}})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      assert Enum.empty?(find_elements(html, "#data-dictionary-field-editor > .error-msg"))
    end

    data_test "schema field name #{name} makes dataset validity to be #{valid?}", %{conn: conn, org_id: org_id} do
      schema = [%{name: name, type: "boolean"}]

      smrt_dataset = TDG.create_dataset(%{organization_id: org_id, technical: %{schema: schema}})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      assert Enum.empty?(find_elements(html, ".data-dictionary-field-editor__name > .error-msg")) == valid?

      where([
        [:name, :valid?],
        ["abc", true],
        ["123", true],
        ["spaces spaces ", true],
        ["dash-dash_underscore", true],
        ["!#$$()", true],
        [~s(control \t \n characters), false]
      ])
    end
  end

  describe "certain fields in the data dictionary editor are unavaliable for non curator users" do
    setup %{public_subject: public_subject} do
      {:ok, public_user} = Andi.Schemas.User.create_or_update(public_subject, %{email: "bob@example.com"})
      [public_user: public_user]
    end

    data_test "PII, Rationale, Demographics, Bias fields are removed", %{public_conn: conn, public_user: public_user} do
      blank_dataset = %Dataset{id: UUID.uuid4(), technical: %{}, business: %{}}

      {:ok, andi_dataset} = Datasets.update(blank_dataset)
      {:ok, _} = Datasets.update(andi_dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)

      assert Enum.empty?(find_elements(html, ".#{selector_name}"))

      where([
        [:selector_name],
        ["data-dictionary-field-editor__pii"],
        ["data-dictionary-field-editor__masked"],
        ["data-dictionary-field-editor__demographic"],
        ["data-dictionary-field-editor__biased"],
        ["data-dictionary-field-editor__rationale"]
      ])
    end
  end

  defp remove_field_from_schema(schema, field_key) do
    schema_head = schema |> hd()

    if field_key in Map.keys(schema_head) do
      schema_head
      |> Map.put(field_key, "")
      |> List.wrap()
    end
  end
end
