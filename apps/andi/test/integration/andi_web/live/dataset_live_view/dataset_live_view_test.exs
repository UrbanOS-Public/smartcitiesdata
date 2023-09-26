defmodule AndiWeb.DatasetLiveViewTest do
  use ExUnit.Case
  use AndiWeb.Test.PublicAccessCase
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo

  import Checkov

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest

  import FlokiHelpers,
    only: [
      find_elements: 2,
      get_text: 2,
      get_value: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper, only: [eventually: 1]
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.MessageErrors

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets"

  describe "non-curator view" do
    test "only datasets owned by the user are shown", %{public_conn: conn, public_subject: subject} do
      {:ok, _dataset_a} = TDG.create_dataset(business: %{orgTitle: "org_a"}) |> Datasets.update()
      {:ok, _dataset_b} = TDG.create_dataset(business: %{orgTitle: "org_b"}) |> Datasets.update()
      {:ok, user} = Andi.Schemas.User.create_or_update(subject, %{email: "bob@example.com", name: "bob"})
      Datasets.create(user)

      {:ok, _view, html} = live(conn, @url_path)

      dataset_rows = find_elements(html, ".datasets-table__tr")

      assert Enum.count(dataset_rows) == 1
    end

    test "edit button links to the submission edit page", %{public_conn: conn, public_subject: subject} do
      {:ok, user} = Andi.Schemas.User.create_or_update(subject, %{email: "bob@example.com", name: "Bob"})
      dataset = Datasets.create(user)

      {:ok, view, _html} = live(conn, @url_path)

      edit_dataset_button = element(view, ".btn", "Edit")

      render_click(edit_dataset_button)
      assert_redirected(view, "/submissions/#{dataset.id}")
    end
  end

  describe "curator view" do
    test "all datasets are shown", %{curator_conn: conn, public_subject: subject} do
      {:ok, _dataset_a} = TDG.create_dataset(business: %{orgTitle: "org_a"}) |> Datasets.update()
      {:ok, _dataset_b} = TDG.create_dataset(business: %{orgTitle: "org_b"}) |> Datasets.update()
      {:ok, user} = Andi.Schemas.User.create_or_update(subject, %{email: "bob@example.com", name: "Bob"})
      Datasets.create(user)

      {:ok, _view, html} = live(conn, @url_path)

      dataset_rows = find_elements(html, ".datasets-table__tr")

      assert Enum.count(dataset_rows) >= 3
    end

    test "edit button links to the admin edit page", %{curator_conn: conn, public_subject: subject} do
      {:ok, user} = Andi.Schemas.User.create_or_update(subject, %{email: "bob@example.com", name: "Bob"})
      dataset = Datasets.create(user)

      {:ok, view, _html} = live(conn, @url_path)

      edit_dataset_button = element(view, ".btn", "Edit")

      render_click(edit_dataset_button)
      assert_redirected(view, "/datasets/#{dataset.id}")
    end
  end

  describe "dataset status" do
    data_test "is #{inspect(submission_status)} if dataset has not been ingested", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      {:ok, andi_dataset} = Datasets.update(dataset)

      Datasets.update_submission_status(dataset.id, submission_status)

      assert {:ok, view, html} = live(conn, @url_path)

      assert andi_dataset.dlq_message == nil
      table_row = get_dataset_table_row(html, dataset)

      status_modifier = Atom.to_string(submission_status)
      refute Enum.empty?(Floki.find(table_row, ".dataset__status--#{status_modifier}"))

      where([
        [:submission_status],
        [:published],
        [:approved],
        [:rejected],
        [:submitted],
        [:draft]
      ])
    end

    test "defaults submission status to draft", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      {:ok, andi_dataset} = Datasets.update(dataset)

      assert {:ok, view, html} = live(conn, @url_path)

      assert andi_dataset.dlq_message == nil
      table_row = get_dataset_table_row(html, dataset)

      refute Enum.empty?(Floki.find(table_row, ".dataset__status--draft"))
    end

    test "shows success when there is not a current message error on the dataset and no error in the last 7 days", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      {:ok, andi_dataset} = Datasets.update(dataset)
      current_time = DateTime.utc_now()
      Datasets.update_ingested_time(dataset.id, current_time)
      Datasets.update_submission_status(dataset.id, :approved)

      message_error = %{
        dataset_id: dataset.id,
        has_current_error: false,
        last_error_time: DateTime.add(current_time, -7 * 24 * 3600)
      }

      MessageErrors.update(message_error)

      assert {:ok, view, html} = live(conn, @url_path)

      assert andi_dataset.dlq_message == nil
      table_row = get_dataset_table_row(html, dataset)

      refute Enum.empty?(Floki.find(table_row, ".dataset__status--success"))
    end

    test "shows partial success when there is not a current message error on the dataset and there is an error in the last 7 days", %{
      conn: conn
    } do
      dataset = TDG.create_dataset(%{})
      {:ok, andi_dataset} = Datasets.update(dataset)
      current_time = DateTime.utc_now()
      Datasets.update_ingested_time(dataset.id, current_time)
      Datasets.update_submission_status(dataset.id, :approved)

      message_error = %{
        dataset_id: dataset.id,
        has_current_error: false,
        last_error_time: DateTime.add(current_time, -6 * 24 * 3600)
      }

      MessageErrors.update(message_error)

      assert {:ok, view, html} = live(conn, @url_path)

      assert andi_dataset.dlq_message == nil
      table_row = get_dataset_table_row(html, dataset)

      refute Enum.empty?(Floki.find(table_row, ".dataset__status--partial-success"))
    end

    test "shows error when there is a current message error on the dataset", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      {:ok, _} = Datasets.update(dataset)
      current_time = DateTime.utc_now()
      Datasets.update_ingested_time(dataset.id, current_time)
      Datasets.update_submission_status(dataset.id, :approved)

      message_error = %{
        dataset_id: dataset.id,
        has_current_error: true,
        last_error_time: current_time
      }

      MessageErrors.update(message_error)

      assert {:ok, view, html} = live(conn, @url_path)
      table_row = get_dataset_table_row(html, dataset)

      refute Enum.empty?(Floki.find(table_row, ".dataset__status--error"))
    end
  end

  describe "add dataset button for curator" do
    setup do
      on_exit(set_access_level(:private))
      restart_andi()

      Ecto.Adapters.SQL.Sandbox.checkout(Andi.Repo)
      Ecto.Adapters.SQL.Sandbox.mode(Andi.Repo, {:shared, self()})

      :ok
    end

    test "add dataset button creates a dataset with a default dataTitle and dataName", %{curator_conn: conn, curator_subject: subject} do
      allow(AndiWeb.Endpoint.broadcast_from(any(), any(), any(), any()), return: :ok, meck_options: [:passthrough])

      {:ok, _user} = Andi.Schemas.User.create_or_update(subject, %{email: "bob@example.com", name: "Bob"})
      assert {:ok, view, _html} = live(conn, @url_path)

      {:error, {:live_redirect, %{kind: :push, to: edit_page}}} = render_click(view, "add-dataset")

      assert {:ok, view, html} = live(conn, edit_page)
      metadata_view = find_live_child(view, "metadata_form_editor")

      assert "New Dataset - #{Date.utc_today()}" == get_value(html, "#form_data_dataTitle")

      assert "new_dataset_#{Date.utc_today() |> to_string() |> String.replace("-", "", global: true)}" ==
               get_value(html, "#form_data_dataName")

      html = render_change(metadata_view, :save)

      refute Enum.empty?(find_elements(html, "#description-error-msg"))
    end

    test "add dataset button creates a dataset with the owner as the currently logged in user", %{
      curator_conn: conn,
      curator_subject: subject
    } do
      {:ok, user} = Andi.Schemas.User.create_or_update(subject, %{email: "bob@example.com", name: "Bob"})
      assert {:ok, view, _html} = live(conn, @url_path)

      {:error, {:live_redirect, %{kind: :push, to: edit_page}}} = render_click(view, "add-dataset")

      assert {:ok, view, html} = live(conn, edit_page)

      owned_dataset =
        Andi.InputSchemas.Datasets.get_all()
        |> Enum.filter(fn dataset -> dataset.owner_id == user.id end)
        |> List.first()

      refute owned_dataset == nil
      assert owned_dataset.business.contactEmail == user.email
    end

    test "add dataset button creates a dataset with release date and updated date defaulted to today", %{
      curator_conn: conn,
      curator_subject: subject
    } do
      expected_date = Date.utc_today()
      {:ok, user} = Andi.Schemas.User.create_or_update(subject, %{email: "bob@example.com", name: "Bob"})
      assert {:ok, view, _html} = live(conn, @url_path)

      {:error, {:live_redirect, %{kind: :push, to: edit_page}}} = render_click(view, "add-dataset")

      assert {:ok, view, html} = live(conn, edit_page)

      owned_dataset =
        Andi.InputSchemas.Datasets.get_all()
        |> Enum.filter(fn dataset -> dataset.owner_id == user.id end)
        |> List.first()

      refute owned_dataset == nil
      assert owned_dataset.business.issuedDate == expected_date
      assert owned_dataset.business.modifiedDate == expected_date
    end

    test "does not load datasets that only contain a timestamp", %{conn: conn} do
      dataset_with_only_timestamp = %Dataset{
        id: UUID.uuid4(),
        ingestedTime: DateTime.utc_now(),
        business: %{dataTitle: "baaaaad dataset"},
        technical: %{}
      }

      Datasets.update(dataset_with_only_timestamp)

      assert {:ok, _view, html} = live(conn, @url_path)
      table_text = get_text(html, ".datasets-index__table")

      refute dataset_with_only_timestamp.business.dataTitle =~ table_text
    end
  end

  describe "add dataset button for non-curator" do
    test "add dataset button creates a dataset with a default dataTitle and dataName", %{public_conn: conn, public_subject: subject} do
      allow(AndiWeb.Endpoint.broadcast_from(any(), any(), any(), any()), return: :ok, meck_options: [:passthrough])

      {:ok, _user} = Andi.Schemas.User.create_or_update(subject, %{email: "bob@example.com", name: "Bob"})
      assert {:ok, view, _html} = live(conn, @url_path)

      {:error, {:live_redirect, %{kind: :push, to: edit_page}}} = render_click(view, "add-dataset")

      assert {:ok, view, html} = live(conn, edit_page)
      metadata_view = find_live_child(view, "metadata_form_editor")

      assert "New Dataset - #{Date.utc_today()}" == get_value(html, "#form_data_dataTitle")

      assert "new_dataset_#{Date.utc_today() |> to_string() |> String.replace("-", "", global: true)}" ==
               get_value(html, "#form_data_dataName")

      html = render_change(metadata_view, :save)

      refute Enum.empty?(find_elements(html, "#description-error-msg"))
    end

    test "add dataset button creates a dataset with the owner as the currently logged in user", %{
      public_conn: conn,
      public_subject: subject
    } do
      {:ok, user} = Andi.Schemas.User.create_or_update(subject, %{email: "bob@example.com", name: "Bob"})
      assert {:ok, view, _html} = live(conn, @url_path)

      {:error, {:live_redirect, %{kind: :push, to: edit_page}}} = render_click(view, "add-dataset")

      assert {:ok, view, html} = live(conn, edit_page)

      owned_dataset =
        Andi.InputSchemas.Datasets.get_all()
        |> Enum.filter(fn dataset -> dataset.owner_id == user.id end)
        |> List.first()

      refute owned_dataset == nil
      assert owned_dataset.business.contactEmail == user.email
    end

    test "add dataset button creates a dataset with release date and updated date defaulted to today", %{
      public_conn: conn,
      public_subject: subject
    } do
      expected_date = Date.utc_today()
      {:ok, user} = Andi.Schemas.User.create_or_update(subject, %{email: "bob@example.com", name: "Bob"})
      assert {:ok, view, _html} = live(conn, @url_path)

      {:error, {:live_redirect, %{kind: :push, to: edit_page}}} = render_click(view, "add-dataset")

      assert {:ok, view, html} = live(conn, edit_page)

      owned_dataset =
        Andi.InputSchemas.Datasets.get_all()
        |> Enum.filter(fn dataset -> dataset.owner_id == user.id end)
        |> List.first()

      refute owned_dataset == nil
      assert owned_dataset.business.issuedDate == expected_date
      assert owned_dataset.business.modifiedDate == expected_date
    end
  end

  test "does not load datasets that only contain a timestamp", %{conn: conn} do
    dataset_with_only_timestamp = %Dataset{
      id: UUID.uuid4(),
      ingestedTime: DateTime.utc_now(),
      business: %{dataTitle: "baaaaad dataset"},
      technical: %{}
    }

    Datasets.update(dataset_with_only_timestamp)

    assert {:ok, _view, html} = live(conn, @url_path)
    table_text = get_text(html, ".datasets-index__table")

    refute dataset_with_only_timestamp.business.dataTitle =~ table_text
  end

  describe "When form submit executes search" do
    test "filters on orgTitle", %{conn: conn} do
      {:ok, dataset_a} = TDG.create_dataset(business: %{orgTitle: "org_a"}) |> Datasets.update()
      {:ok, dataset_b} = TDG.create_dataset(business: %{orgTitle: "org_b"}) |> Datasets.update()

      {:ok, view, _html} = live(conn, @url_path)

      html = render_submit(view, :search, %{"search-value" => dataset_a.business.orgTitle})

      assert get_text(html, ".datasets-index__table") =~ dataset_a.business.orgTitle
      refute get_text(html, ".datasets-index__table") =~ dataset_b.business.orgTitle
    end

    test "filters on dataTitle", %{conn: conn} do
      {:ok, dataset_a} = TDG.create_dataset(business: %{dataTitle: "data_a"}) |> Datasets.update()
      {:ok, dataset_b} = TDG.create_dataset(business: %{dataTitle: "data_b"}) |> Datasets.update()

      {:ok, view, _html} = live(conn, @url_path)

      html = render_submit(view, :search, %{"search-value" => dataset_a.business.dataTitle})

      assert get_text(html, ".datasets-index__table") =~ dataset_a.business.dataTitle
      refute get_text(html, ".datasets-index__table") =~ dataset_b.business.dataTitle
    end

    test "shows No Datasets if no results returned", %{conn: conn} do
      {:ok, _dataset_a} = TDG.create_dataset(business: %{dataTitle: "data_a"}) |> Datasets.update()
      {:ok, _dataset_b} = TDG.create_dataset(business: %{dataTitle: "data_b"}) |> Datasets.update()

      {:ok, view, _html} = live(conn, @url_path)

      html = render_change(view, :search, %{"search-value" => "__NOT_RESULTS_SHOULD RETURN__"})

      assert get_text(html, ".datasets-index__table") =~ "No Datasets"
    end

    test "Search Submit succeeds even with missing fields", %{conn: conn} do
      {:ok, dataset_a} =
        TDG.create_dataset(business: %{orgTitle: "org_a"})
        |> put_in([:business, :dataTitle], nil)
        |> Datasets.update()

      {:ok, dataset_b} =
        TDG.create_dataset(business: %{dataTitle: "data_b"})
        |> put_in([:business, :orgTitle], nil)
        |> Datasets.update()

      {:ok, view, _html} = live(conn, @url_path)

      html = render_submit(view, :search, %{"search-value" => dataset_a.business.orgTitle})

      assert get_text(html, ".datasets-index__table") =~ dataset_a.business.orgTitle
      refute get_text(html, ".datasets-index__table") =~ dataset_b.business.dataTitle
    end
  end

  defp get_dataset_table_row(html, dataset) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find(".datasets-table__tr")
    |> Enum.reduce_while([], fn row, _acc ->
      {_, _, children} = row

      [{_, _, [row_title]}] =
        children
        |> Floki.find(".datasets-table__data-title-cell")

      case dataset.business.dataTitle == row_title do
        true -> {:halt, row}
        false -> {:cont, []}
      end
    end)
  end
end
