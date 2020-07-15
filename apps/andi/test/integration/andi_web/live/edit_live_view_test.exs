defmodule AndiWeb.EditLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.ConnCase
  use Placebo
  import Checkov

  alias Andi.Services.DatasetStore
  alias Andi.Services.OrgStore
  alias Andi.Services.UrlTest

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import Andi, only: [instance_name: 0]
  import SmartCity.Event, only: [dataset_update: 0, organization_update: 0]
  import SmartCity.TestHelper, only: [eventually: 1, eventually: 3]

  import FlokiHelpers,
    only: [
      get_attributes: 3,
      get_value: 2,
      get_values: 2,
      get_select: 2,
      get_all_select_options: 2,
      get_select_first_option: 2,
      get_text: 2,
      get_texts: 2,
      find_elements: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.DataDictionaryFields
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.FormTools
  alias Andi.InputSchemas.InputConverter

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets/"

  describe "finalize form" do
    setup do
      dataset = TDG.create_dataset(%{technical: %{cadence: "1 1 1 * * *"}})

      {:ok, andi_dataset} = Datasets.update(dataset)
      [dataset: andi_dataset]
    end

    data_test "quick schedule #{schedule}", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      render_click([view, "finalize_form"], "quick_schedule", %{"schedule" => schedule})
      html = render(view)

      assert expected_crontab == get_crontab_from_html(html)
      assert Enum.empty?(find_elements(html, "#cadence-error-msg"))

      where([
        [:schedule, :expected_crontab],
        ["hourly", "0 0 * * * *"],
        ["daily", "0 0 0 * * *"],
        ["weekly", "0 0 0 * * 0"],
        ["monthly", "0 0 0 1 * *"],
        ["yearly", "0 0 0 1 1 *"]
      ])
    end

    test "set schedule manually", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)
      render_change(view, :save, %{"form_data" => form_data})
      html = render(view)

      assert dataset.technical.cadence == get_crontab_from_html(html)
      assert Enum.empty?(find_elements(html, "#cadence-error-msg"))
    end

    test "handles five-character cronstrings", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{cadence: "4 2 7 * *"}})
      {:ok, andi_dataset} = Datasets.update(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(andi_dataset)
      render_change(view, :save, %{"form_data" => form_data})
      html = render(view)

      assert dataset.technical.cadence == get_crontab_from_html(html)
      assert Enum.empty?(find_elements(html, "#cadence-error-msg"))
    end

    test "handles cadence of never", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{cadence: "never"}})
      {:ok, _} = Datasets.update(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert Enum.empty?(find_elements(html, "#cadence-error-msg"))
    end
  end

  describe "dataset finalizing buttons" do
    test "allows saving invalid form as draft", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      {:ok, andi_dataset} = Datasets.update(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(andi_dataset) |> put_in([:business, :dataTitle], "")
      form_data_changeset = InputConverter.form_data_to_full_changeset(%Dataset{}, form_data)

      render_change(view, :validate, %{"form_data" => form_data})
      html = render_change(view, :save, %{"form_data" => form_data})

      refute form_data_changeset.valid?
      assert Datasets.get(dataset.id) |> get_in([:business, :dataTitle]) == ""
      assert get_text(html, "#form_data_business_dataTitle") == ""
      refute Enum.empty?(find_elements(html, "#dataTitle-error-msg"))
    end
  end

  describe "save and publish form data" do
    test "valid form data is saved on publish", %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          business: %{modifiedDate: "2020-01-04T01:02:03Z"}
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :issuedDate], "2020-01-03")

      render_change(view, :validate, %{"form_data" => form_data})
      render_change(view, :publish)

      dataset = Datasets.get(dataset.id)
      {:ok, saved_dataset} = InputConverter.andi_dataset_to_smrt_dataset(dataset)

      eventually(fn ->
        assert {:ok, ^saved_dataset} = DatasetStore.get(dataset.id)
      end)
    end

    test "invalid form data is not saved on publish", %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          business: %{publishFrequency: "I dunno, whenever, I guess"}
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :publishFrequency], "")

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      render_change(view, :validate, %{"form_data" => form_data})
      render_change(view, :publish)

      eventually(fn ->
        assert %{business: %{publishFrequency: "I dunno, whenever, I guess"}} = Datasets.get(dataset.id)
      end)
    end

    test "success message is displayed when form data is saved", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{issuedDate: nil}})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_text(html, "#snackbar") == ""

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :issuedDate], "2020-01-03")

      html = render_change(view, :save, %{"form_data" => form_data})

      refute Enum.empty?(find_elements(html, "#snackbar.success-message"))
      assert get_text(html, "#snackbar") != ""
    end

    test "saving form as draft does not send brook event", %{conn: conn} do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)
      smrt_dataset = TDG.create_dataset(%{business: %{issuedDate: nil}})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)

      render_change(view, :save, %{"form_data" => form_data})

      refute_called Brook.Event.send(any(), any(), any(), any())
    end

    test "saving form as draft with invalid changes warns user", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{dataTitle: ""}})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, _} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)

      html = render_change(view, :save, %{"form_data" => form_data})

      assert get_text(html, "#snackbar") == "Saved successfully. You may need to fix errors before publishing."
    end

    test "allows clearing modified date", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{modifiedDate: "2020-01-01T00:00:00Z"}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :modifiedDate], nil)

      render_change(view, :validate, %{"form_data" => form_data})
      render_change(view, :publish)

      eventually(fn ->
        assert {:ok, nil} != DatasetStore.get(dataset.id)
      end)
    end

    test "does not save when dataset org and data name match existing dataset", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, dataset} = Datasets.update(smrt_dataset)
      {:ok, other_dataset} = Datasets.update(TDG.create_dataset(%{}))

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:technical, :dataName], other_dataset.technical.dataName)
        |> put_in([:technical, :orgName], other_dataset.technical.orgName)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      render_change(view, :validate, %{"form_data" => form_data})
      render_change(view, :validate_system_name)
      render_change(view, :publish)

      assert render(view) |> get_text("#snackbar") =~ "errors"
    end

    data_test "allows saving with empty #{field}", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{field => %{"x" => "y"}}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> Map.update!(:technical, &Map.delete(&1, field))

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      render_change(view, :validate, %{"form_data" => form_data})
      render_change(view, :publish)

      dataset = Datasets.get(dataset.id)
      {:ok, saved_dataset} = InputConverter.andi_dataset_to_smrt_dataset(dataset)

      eventually(fn ->
        assert {:ok, ^saved_dataset} = DatasetStore.get(dataset.id)
      end)

      where(field: [:sourceQueryParams, :sourceHeaders])
    end

    test "alert shows when section changes are unsaved on cancel action", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        dataset
        |> put_in([:business, :dataTitle], "a new datset title")
        |> FormTools.form_data_from_andi_dataset()

      render_change(view, "validate", %{"form_data" => form_data})

      refute [] == find_elements(html, ".unsaved-changes-modal--hidden")

      render_change(view, "cancel-edit", %{})

      html = render(view)

      refute [] == find_elements(html, ".unsaved-changes-modal--visible")
    end

    test "clicking continues takes you back to the datasets page without saved changes", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        dataset
        |> put_in([:business, :dataTitle], "a new datset title")
        |> FormTools.form_data_from_andi_dataset()

      render_change(view, "validate", %{"form_data" => form_data})

      render_change(view, "cancel-edit", %{})

      html = render(view)

      refute [] == find_elements(html, ".unsaved-changes-modal--visible")

      render_change(view, "force-cancel-edit", %{})

      assert_redirect(view, "/")
    end
  end

  defp get_crontab_from_html(html) do
    html
    |> get_values(".finalize-form-schedule-input__field")
    |> Enum.join(" ")
    |> String.trim_leading()
  end
end
