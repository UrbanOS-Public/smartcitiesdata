defmodule AndiWeb.EditLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo
  import Checkov

  alias Andi.Services.DatasetStore

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1, eventually: 3]

  import FlokiHelpers, only: [get_attributes: 3, get_text: 2, find_elements: 2]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.InputConverter
  alias Andi.Test.AuthHelper

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets/"

  setup do
    {:ok, curator} = Andi.Schemas.User.create_or_update(AuthHelper.valid_subject_id(), %{email: "bob@example.com"})
    {:ok, public_user} = Andi.Schemas.User.create_or_update(AuthHelper.valid_public_subject_id(), %{email: "bob@example.com"})
    [curator: curator, public_user: public_user]
  end

  describe "public access to edit datasets" do
    setup do
      [conn: Andi.Test.AuthHelper.build_authorized_conn(jwt: AuthHelper.valid_public_jwt())]
    end

    test "public user can access their own dataset", %{conn: conn, public_user: public_user} do
      dataset = Datasets.create(public_user)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    end

    test "public user cannot access an unowned dataset", %{conn: conn} do
      {:ok, dataset} = TDG.create_dataset(%{}) |> Datasets.update()

      get(conn, @url_path <> dataset.id)
      |> response(404)
    end

    test "public user cannot access a dataset owned by another user", %{conn: conn, curator: curator} do
      dataset = Datasets.create(curator)

      get(conn, @url_path <> dataset.id)
      |> response(404)
    end
  end

  describe "curator access to edit datasets" do
    setup do
      [conn: Andi.Test.AuthHelper.build_authorized_conn(jwt: AuthHelper.valid_jwt())]
    end

    test "curator can access their own dataset", %{conn: conn, curator: curator} do
      dataset = Datasets.create(curator)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    end

    test "curator can access an unowned dataset", %{conn: conn} do
      {:ok, dataset} = TDG.create_dataset(%{}) |> Datasets.update()
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    end

    test "curator can access a dataset owned by another user", %{conn: conn, public_user: public_user} do
      dataset = Datasets.create(public_user)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    end
  end

  describe "save and publish form data" do
    test "save button in one section saves all sections", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{cadence: "never"}})
      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      finalize_view = find_child(view, "finalize_form_editor")
      url_view = find_child(view, "url_form_editor")

      form_data = %{"cadence" => "once"}

      render_change(finalize_view, :validate, %{"form_data" => form_data})
      render_change(url_view, :save)

      eventually(fn ->
        dataset = Datasets.get(dataset.id)

        assert "once" == dataset.technical.cadence
      end)
    end

    test "publish button saves all sections", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      finalize_view = find_child(view, "finalize_form_editor")
      metadata_view = find_child(view, "metadata_form_editor")

      finalize_form_data = %{"cadence" => "once"}
      metadata_form_data = %{"description" => "cambapo"}

      render_change(finalize_view, :validate, %{"form_data" => finalize_form_data})
      render_change(metadata_view, :validate, %{"form_data" => metadata_form_data})

      render_change(finalize_view, :publish)

      eventually(fn ->
        dataset = Datasets.get(dataset.id)

        assert "once" == dataset.technical.cadence
        assert "cambapo" == dataset.business.description
      end)
    end

    test "valid form data is saved on publish", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      finalize_view = find_child(view, "finalize_form_editor")

      form_data = %{"cadence" => "once"}

      render_change(finalize_view, :validate, %{"form_data" => form_data})
      render_change(finalize_view, :publish)

      eventually(
        fn ->
          dataset = Datasets.get(dataset.id)
          {:ok, saved_dataset} = InputConverter.andi_dataset_to_smrt_dataset(dataset)

          assert {:ok, ^saved_dataset} = DatasetStore.get(dataset.id)
        end,
        10,
        1_000
      )
    end

    test "invalid form data is saved on publish", %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          business: %{publishFrequency: "I dunno, whenever, I guess"}
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)
      assert "I dunno, whenever, I guess" == Datasets.get(dataset.id) |> get_in([:business, :publishFrequency])

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_child(view, "metadata_form_editor")
      finalize_view = find_child(view, "finalize_form_editor")

      form_data = %{"publishFrequency" => nil}

      render_change(metadata_view, :validate, %{"form_data" => form_data})
      render_change(finalize_view, :publish)

      Process.sleep(2_000)
      assert nil == Datasets.get(dataset.id) |> get_in([:business, :publishFrequency])
    end

    test "success message is displayed when form data is saved", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      finalize_view = find_child(view, "finalize_form_editor")

      assert get_text(html, "#snackbar") == ""

      render_change(finalize_view, :save, %{})
      html = render(view)

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
      url_view = find_child(view, "url_form_editor")

      render_change(url_view, :save, %{})

      refute_called Brook.Event.send(any(), any(), any(), any())
    end

    test "saving form as draft with invalid changes warns user", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{dataTitle: ""}})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, _} = live(conn, @url_path <> dataset.id)
      metadata_view = find_child(view, "metadata_form_editor")

      form_data = %{"dataTitle" => ""}

      render_change(metadata_view, :validate, %{"form_data" => form_data})
      render_change(metadata_view, :save, %{})
      html = render(view)

      assert get_text(html, "#snackbar") == "Saved successfully. You may need to fix errors before publishing."
    end

    test "allows clearing modified date", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{modifiedDate: "2020-01-01T00:00:00Z"}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_child(view, "metadata_form_editor")
      finalize_view = find_child(view, "finalize_form_editor")

      form_data = %{
        "modifiedDate" => "",
        "dataName" => "somethimn",
        "orgName" => "something",
        "private" => false,
        "sourceFormat" => "something",
        "sourceType" => "something",
        "benefitRating" => 1.0,
        "contactEmail" => "something@something.com",
        "contactName" => "something",
        "dataTitle" => "something",
        "description" => "something",
        "issuedDate" => ~D[1899-10-20],
        "license" => "https://www.test.net",
        "orgTitle" => "something",
        "publishFrequency" => "something",
        "riskRating" => 1.0
      }

      render_change(metadata_view, :validate, %{"form_data" => form_data})
      render_change(finalize_view, :publish)

      eventually(
        fn ->
          assert {:ok, nil} != DatasetStore.get(dataset.id)
        end,
        30,
        1_000
      )
    end

    test "does not save when dataset org and data name match existing dataset", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, dataset} = Datasets.update(smrt_dataset)
      {:ok, other_dataset} = Datasets.update(TDG.create_dataset(%{}))

      form_data = %{"dataTitle" => other_dataset.technical.dataName, "orgName" => other_dataset.technical.orgName}

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_child(view, "metadata_form_editor")
      finalize_view = find_child(view, "finalize_form_editor")

      render_change(metadata_view, :validate, %{"form_data" => form_data, "_target" => ["form_data", "dataTitle"]})
      render_change(metadata_view, :validate_system_name, %{})
      render_change(finalize_view, :publish)

      assert render(view) |> get_text("#snackbar") =~ "errors"
    end

    data_test "allows saving with empty #{field}", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{field => %{"x" => "y"}}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      form_data = %{"sourceUrl" => "cam.com", field => %{"x" => "y"}}

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      url_view = find_child(view, "url_form_editor")
      finalize_view = find_child(view, "finalize_form_editor")

      render_change(url_view, :validate, %{"form_data" => form_data})
      render_change(finalize_view, :publish)

      eventually(
        fn ->
          dataset = Datasets.get(dataset.id)
          {:ok, saved_dataset} = InputConverter.andi_dataset_to_smrt_dataset(dataset)
          assert {:ok, ^saved_dataset} = DatasetStore.get(dataset.id)
        end,
        20,
        500
      )

      where(field: ["sourceQueryParams", "sourceHeaders"])
    end

    test "alert shows when section changes are unsaved on cancel action", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_child(view, "metadata_form_editor")

      form_data = %{"dataTitle" => "new dataset title"}

      render_change(metadata_view, "validate", %{"form_data" => form_data})

      refute Enum.empty?(find_elements(html, ".unsaved-changes-modal--hidden"))

      render_change(metadata_view, "cancel-edit", %{})
      html = render(view)

      refute Enum.empty?(find_elements(html, ".unsaved-changes-modal--visible"))
    end

    test "clicking cancel takes you back to the datasets page without saved changes", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_child(view, "metadata_form_editor")

      form_data = %{"dataTitle" => "new dataset title"}

      render_change(metadata_view, "validate", %{"form_data" => form_data})
      render_change(metadata_view, "cancel-edit", %{})
      html = render(view)

      refute Enum.empty?(find_elements(html, ".unsaved-changes-modal--visible"))

      render_change(view, "force-cancel-edit", %{})

      assert "new dataset title" != Datasets.get(dataset.id) |> get_in([:business, :dataTitle])

      assert_redirect(view, "/")
    end

    test "successfully publishing presents modal", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      finalize_view = find_child(view, "finalize_form_editor")

      form_data = %{"cadence" => "once"}

      render_change(finalize_view, :validate, %{"form_data" => form_data})
      render_change(finalize_view, :publish)
      html = render(view)

      refute Enum.empty?(find_elements(html, ".publish-success-modal--visible"))
    end

    test "continuing to edit after publish reloads the page", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert Enum.empty?(get_attributes(html, "#form_data_sourceFormat", "disabled"))

      finalize_view = find_child(view, "finalize_form_editor")
      form_data = %{"cadence" => "once"}

      render_change(finalize_view, :validate, %{"form_data" => form_data})
      render_change(finalize_view, :publish)
      html = render(view)

      eventually(fn ->
        assert !Enum.empty?(find_elements(html, ".publish-success-modal--visible"))
      end)

      render_change(view, "reload-page", %{})
      url = @url_path <> dataset.id

      assert_redirect(view, url)
    end
  end

  describe "delete dataset" do
    test "dataset is deleted after confirmation", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      render_change(view, "confirm-delete", %{"id" => dataset.id})

      eventually(fn ->
        assert nil == Datasets.get(dataset.id)
      end)
    end
  end
end
