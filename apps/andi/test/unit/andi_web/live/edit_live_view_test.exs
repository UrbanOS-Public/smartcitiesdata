defmodule AndiWeb.EditLiveViewTest do
  use AndiWeb.ConnCase
  use Phoenix.ConnTest
  use Placebo

  import Phoenix.LiveViewTest
  import Checkov

  import SmartCity.Event, only: [dataset_update: 0]
  import Andi, only: [instance_name: 0]

  import SmartCity.TestHelper

  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.FormTools
  alias Andi.Services.UrlTest

  import FlokiHelpers,
    only: [
      find_elements: 2,
      get_attributes: 3,
      get_select: 2,
      get_text: 2,
      get_value: 2,
      get_values: 2
    ]

  @url_path "/datasets/"

  describe "enter form data" do
    test "display Level of Access as public when private is false", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{technical: %{private: false}})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      assert {"false", "Public"} = get_select(html, ".metadata-form__level-of-access")
    end

    test "display Level of Access as private when private is true", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{technical: %{private: true}})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      assert {"true", "Private"} = get_select(html, ".metadata-form__level-of-access")
    end

    test "the default language is set to english", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      assert {"english", "English"} = get_select(html, ".metadata-form__language")
    end

    test "the language is set to spanish", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{business: %{language: "spanish"}})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {"spanish", "Spanish"} = get_select(html, ".metadata-form__language")
    end

    test "the language is changed from english to spanish", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :language], "spanish")

      html = render_change(view, :validate, %{"form_data" => form_data})

      assert {"spanish", "Spanish"} = get_select(html, ".metadata-form__language")
    end

    data_test "benefit rating is set to '#{label}' (#{inspect(value)})", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{business: %{benefitRating: value}})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {to_string(value), label} == get_select(html, ".metadata-form__benefit-rating")

      where([
        [:value, :label],
        [0.0, "Low"],
        [0.5, "Medium"],
        [1.0, "High"]
      ])
    end

    data_test "risk rating is set to '#{label}' (#{inspect(value)})", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{business: %{riskRating: value}})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {to_string(value), label} == get_select(html, ".metadata-form__risk-rating")

      where([
        [:value, :label],
        [0.0, "Low"],
        [0.5, "Medium"],
        [1.0, "High"]
      ])
    end

    data_test "errors on invalid email: #{email}", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{business: %{contactEmail: email}})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)

      html = render_change(view, :validate, %{"form_data" => form_data})

      assert get_text(html, "#contactEmail-error-msg") == "Please enter a valid maintainer email."

      where([
        [:email],
        ["foomail.com"]
        # ["kevinspace@"],
        # ["kevinspace@notarealdomain"],
        # ["my little address"]
      ])
    end

    data_test "does not error on valid email: #{email}", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{business: %{contactEmail: email}})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)

      html = render_change(view, :validate, %{"form_data" => form_data})

      assert get_text(html, "#contactEmail-error-msg") == ""

      where([
        [:email],
        ["foo@mail.com"],
        ["kevin@space.org"],
        ["my@little.gov"],
        ["test-email@email.com"]
      ])
    end

    test "adds commas between keywords", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{business: %{keywords: ["one", "two", "three"]}})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      [subject] = get_values(html, ".metadata-form__keywords input")

      assert subject =~ "one, two, three"
    end

    test "keywords input should show empty string if keywords is nil", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{business: %{keywords: nil}})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      [subject] = get_values(html, ".metadata-form__keywords input")

      assert subject == ""
    end

    test "should not add additional commas to keywords", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{})

      DatasetHelpers.add_dataset_to_repo(dataset)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :keywords], Enum.join(dataset.business.keywords, ", "))

      expected = Enum.join(dataset.business.keywords, ", ")

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      html = render_change(view, :validate, %{"form_data" => form_data})

      subject = get_value(html, ".metadata-form__keywords input")

      assert expected == subject
    end

    test "should trim spaces in keywords", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{})

      DatasetHelpers.add_dataset_to_repo(dataset)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :keywords], "a , good ,  keyword   , is .... hard , to find")

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      html = render_change(view, :validate, %{"form_data" => form_data})

      subject = get_value(html, ".metadata-form__keywords input")

      assert "a, good, keyword, is .... hard, to find" == subject
    end

    test "can handle lists of keywords", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{})

      DatasetHelpers.add_dataset_to_repo(dataset)

      expected = Enum.join(dataset.business.keywords, ", ")

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :keywords], expected)

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      html = render_change(view, :validate, %{"form_data" => form_data})

      subject = get_value(html, ".metadata-form__keywords input")

      assert expected == subject
    end

    test "displays all other fields", %{conn: conn} do
      dataset =
        DatasetHelpers.create_dataset(%{
          business: %{
            description: "A description with no special characters",
            benefitRating: 1.0,
            riskRating: 0.5
          },
          technical: %{private: true}
        })

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      assert get_value(html, ".metadata-form__title input") == dataset.business.dataTitle
      assert get_text(html, ".metadata-form__description textarea") == dataset.business.description
      assert get_value(html, ".metadata-form__format input") == dataset.technical.sourceFormat
      assert {"true", "Private"} == get_select(html, ".metadata-form__level-of-access")
      assert get_value(html, ".metadata-form__maintainer-name input") == dataset.business.contactName
      assert dataset.business.modifiedDate |> Date.to_string() =~ get_value(html, ".metadata-form__last-updated input")
      assert get_value(html, ".metadata-form__maintainer-email input") == dataset.business.contactEmail
      assert dataset.business.issuedDate |> Date.to_string() =~ get_value(html, ".metadata-form__release-date input")
      assert get_value(html, ".metadata-form__license input") == dataset.business.license
      assert get_value(html, ".metadata-form__update-frequency input") == dataset.business.publishFrequency
      assert get_value(html, ".metadata-form__spatial input") == dataset.business.spatial
      assert get_value(html, ".metadata-form__temporal input") == dataset.business.temporal
      assert get_value(html, ".metadata-form__organization input") == dataset.business.orgTitle
      assert {"english", "English"} == get_select(html, ".metadata-form__language")
      assert get_value(html, ".metadata-form__homepage input") == dataset.business.homepage
      assert {"1.0", "High"} == get_select(html, ".metadata-form__benefit-rating")
      assert {"0.5", "Medium"} == get_select(html, ".metadata-form__risk-rating")
    end
  end

  describe "edit form data" do
    test "accessibility level must be public or private", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{technical: %{private: true}})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_select(html, ".metadata-form__level-of-access") == {"true", "Private"}

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:technical, :private], false)

      html = render_change(view, :validate, %{"form_data" => form_data})
      assert get_select(html, ".metadata-form__level-of-access") == {"false", "Public"}
    end

    data_test "required #{field} field displays proper error message", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(dataset_override)

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)

      html = render_change(view, :validate, %{"form_data" => form_data})

      assert get_text(html, "##{field}-error-msg") == expected_error_message

      where([
        [:field, :dataset_override, :expected_error_message],
        [:dataTitle, %{business: %{dataTitle: ""}}, "Please enter a valid dataset title."],
        [:description, %{business: %{description: ""}}, "Please enter a valid description."],
        [:contactName, %{business: %{contactName: ""}}, "Please enter a valid maintainer name."],
        [:contactEmail, %{business: %{contactEmail: ""}}, "Please enter a valid maintainer email."],
        [:issuedDate, %{business: %{issuedDate: ""}}, "Please enter a valid release date."],
        [:license, %{business: %{license: ""}}, "Please enter a valid license."],
        [:publishFrequency, %{business: %{publishFrequency: ""}}, "Please enter a valid update frequency."],
        [:orgTitle, %{business: %{orgTitle: ""}}, "Please enter a valid organization."],
        [:sourceUrl, %{technical: %{sourceUrl: ""}}, "Please enter a valid base url."],
        [:license, %{business: %{license: ""}}, "Please enter a valid license."],
        [:benefitRating, %{business: %{benefitRating: ""}}, "Please enter a valid benefit."],
        [:riskRating, %{business: %{riskRating: ""}}, "Please enter a valid risk."]
      ])
    end

    test "required sourceFormat displays proper error message", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:technical, :sourceFormat], "")

      html = render_change(view, :validate, %{"form_data" => form_data})

      assert get_text(html, "#sourceFormat-error-msg") == "Please enter a valid source format."
    end

    data_test "invalid #{field} displays proper error message", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{technical: %{field => %{"foo" => "where's my key"}}})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:technical, field], %{"0" => %{"key" => "", "value" => "where's my key"}})

      html = render_change(view, :validate, %{"form_data" => form_data})

      assert get_text(html, "##{field}-error-msg") == "Please enter valid key(s)."

      where(field: [:sourceQueryParams, :sourceHeaders])
    end

    data_test "displays error when #{field} is unset", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_text(html, "##{field}-error-msg") == ""

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, field], "")

      html = render_change(view, :validate, %{"form_data" => form_data})

      assert get_text(html, "##{field}-error-msg") == expected_error_message

      where([
        [:field, :expected_error_message],
        [:benefitRating, "Please enter a valid benefit."],
        [:riskRating, "Please enter a valid risk."]
      ])
    end

    test "error message is cleared when form is updated", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{business: %{issuedDate: ""}})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)

      html = render_change(view, :validate, %{"form_data" => form_data})

      assert get_text(html, "#issuedDate-error-msg") == "Please enter a valid release date."

      updated_form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :issuedDate], "2020-01-03")

      html = render_change(view, :validate, %{"form_data" => updated_form_data})

      assert get_text(html, "#issuedDate-error-msg") == ""
    end
  end

  describe "can not edit" do
    test "source format", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert get_attributes(html, ".metadata-form__format input", "readonly") == ["readonly"]
    end

    test "organization title", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert get_attributes(html, ".metadata-form__organization input", "readonly") == ["readonly"]
    end
  end

  describe "hidden so form_data has all the validated fields in it" do
    data_test "#{name} is hidden", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{})
      DatasetHelpers.add_dataset_to_repo(dataset)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert get_attributes(html, "#form_data_technical_#{name}", "type") == ["hidden"]

      where([
        [:name],
        ["orgName"],
        ["dataName"],
        ["sourceType"]
      ])
    end
  end

  describe "save and publish form data" do
    test "valid form data is saved on publish", %{conn: conn} do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

      dataset = DatasetHelpers.create_dataset(%{business: %{modifiedDate: "2020-01-04T01:02:03Z"}})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :issuedDate], "2020-01-03")

      dataset_from_save =
        dataset
        |> InputConverter.form_data_to_full_changeset(form_data)
        |> Ecto.Changeset.apply_changes()

      allow(Datasets.update(any()), return: {:ok, dataset_from_save})

      render_change(view, :publish)

      {:ok, saved_dataset} = InputConverter.andi_dataset_to_smrt_dataset(dataset_from_save)

      assert_called(Brook.Event.send(instance_name(), dataset_update(), :andi, saved_dataset), once())
    end

    test "invalid form data is not saved on publish", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{business: %{publishFrequency: ""}})

      DatasetHelpers.add_dataset_to_repo(dataset)

      form_data = FormTools.form_data_from_andi_dataset(dataset)

      dataset_from_save =
        dataset
        |> InputConverter.form_data_to_full_changeset(form_data)
        |> Ecto.Changeset.apply_changes()

      allow(Datasets.update(any()), return: {:ok, dataset_from_save})

      allow(Brook.Event.send(any(), any(), :andi, any()), return: :ok)

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      render_change(view, :save, %{"form_data" => form_data})

      refute_called(Brook.Event.send(instance_name(), dataset_update(), :andi, dataset), once())
    end

    test "success message is displayed when form data is saved", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{business: %{issuedDate: ""}})

      DatasetHelpers.add_dataset_to_repo(dataset)

      allow(Brook.Event.send(any(), any(), :andi, any()), return: :ok)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_text(html, "#snackbar") == ""

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :issuedDate], "2020-01-03")

      dataset_from_save =
        dataset
        |> InputConverter.form_data_to_full_changeset(form_data)
        |> Ecto.Changeset.apply_changes()

      allow(Datasets.update(any()), return: {:ok, dataset_from_save})

      render_change(view, :validate, %{"form_data" => form_data})
      html = render_change(view, :save, %{"form_data" => form_data})

      refute Enum.empty?(find_elements(html, "#snackbar.success-message"))
      assert get_text(html, "#snackbar") != ""
    end

    test "saving form as draft does not send brook event", %{conn: conn} do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)
      dataset = DatasetHelpers.create_dataset(%{business: %{issuedDate: ""}})
      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)

      dataset_from_save =
        dataset
        |> InputConverter.form_data_to_full_changeset(form_data)
        |> Ecto.Changeset.apply_changes()

      allow(Datasets.update(any()), return: {:ok, dataset_from_save})

      render_change(view, :validate, %{"form_data" => form_data})
      render_change(view, :save, %{"form_data" => form_data})

      refute_called Brook.Event.send(any(), any(), any(), any())
    end

    test "saving form as draft with invalid changes warns user", %{conn: conn} do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)
      dataset = DatasetHelpers.create_dataset(%{business: %{dataTitle: ""}})
      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, _} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)

      dataset_from_save =
        dataset
        |> InputConverter.form_data_to_full_changeset(form_data)
        |> Ecto.Changeset.apply_changes()

      allow(Datasets.update(any()), return: {:ok, dataset_from_save})
      html = render_change(view, :save, %{"form_data" => form_data})

      assert get_text(html, "#snackbar") == "Saved successfully. You may need to fix errors before publishing."
    end

    test "allows clearing modified date", %{conn: conn} do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

      dataset = DatasetHelpers.create_dataset(%{business: %{modifiedDate: "2020-01-01"}})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :modifiedDate], nil)

      dataset_from_save =
        dataset
        |> InputConverter.form_data_to_full_changeset(form_data)
        |> Ecto.Changeset.apply_changes()

      allow(Datasets.update(any()), return: {:ok, dataset_from_save})

      render_change(view, :publish)

      {:ok, expected_updated_dataset} = InputConverter.andi_dataset_to_smrt_dataset(dataset_from_save)

      assert_called(Brook.Event.send(instance_name(), dataset_update(), :andi, expected_updated_dataset), once())
    end

    test "does not save when dataset org and data name match existing dataset", %{conn: conn} do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

      dataset = DatasetHelpers.create_dataset(%{business: %{issuedDate: nil}})

      DatasetHelpers.add_dataset_to_repo(dataset, unique: false)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :issuedDate], "2020-01-03")

      dataset_from_save =
        dataset
        |> InputConverter.form_data_to_full_changeset(form_data)
        |> Ecto.Changeset.apply_changes()

      allow(Datasets.update(any()), return: {:ok, dataset_from_save})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      render_change(view, :publish)

      refute_called(Brook.Event.send(any(), any(), any(), any()))

      assert render(view) |> get_text("#snackbar") =~ "errors"
    end

    data_test "allows saving with empty #{field}", %{conn: conn} do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

      dataset = DatasetHelpers.create_dataset(%{technical: %{field => %{"x" => "y"}}})

      DatasetHelpers.add_dataset_to_repo(dataset)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> Map.update!(:technical, &Map.delete(&1, field))

      dataset_from_save =
        dataset
        |> InputConverter.form_data_to_full_changeset(form_data)
        |> Ecto.Changeset.apply_changes()

      allow(Datasets.update(any()), return: {:ok, dataset_from_save})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      render_change(view, :publish)

      {:ok, expected_updated_dataset} = InputConverter.andi_dataset_to_smrt_dataset(dataset_from_save)

      assert_called(Brook.Event.send(instance_name(), dataset_update(), :andi, expected_updated_dataset), once())

      where(field: [:sourceQueryParams, :sourceHeaders])
    end
  end

  describe "sourceUrl testing" do
    @tag capture_log: true
    test "uses provided query params and headers", %{conn: conn} do
      dataset =
        DatasetHelpers.create_dataset(%{
          technical: %{
            sourceUrl: "123.com",
            sourceQueryParams: %{"x" => "y"},
            sourceHeaders: %{"api-key" => "to-my-heart"}
          }
        })

      DatasetHelpers.add_dataset_to_repo(dataset)

      allow(UrlTest.test(any(), any()), return: %{time: 1_000, status: 200})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      render_change(view, :test_url, %{})

      assert_called(UrlTest.test("123.com", query_params: [{"x", "y"}], headers: [{"api-key", "to-my-heart"}]))
    end

    data_test "sourceQueryParams are updated when query params are added to source url", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:technical, :sourceUrl], sourceUrl)

      html =
        render_change(view, :validate, %{
          "form_data" => form_data,
          "_target" => ["form_data", "technical", "sourceUrl"]
        })

      assert get_values(html, ".url-form__source-query-params-key-input") == keys
      assert get_values(html, ".url-form__source-query-params-value-input") == values

      where([
        [:sourceUrl, :keys, :values],
        ["http://example.com?cat=dog", ["cat"], ["dog"]],
        ["http://example.com?cat=dog&foo=bar", ["cat", "foo"], ["dog", "bar"]],
        ["http://example.com?cat=dog&foo+biz=bar", ["cat", "foo biz"], ["dog", "bar"]],
        ["http://example.com?cat=", ["cat"], [""]],
        ["http://example.com?=dog", [""], ["dog"]]
      ])
    end

    data_test "sourceUrl is updated when query params are added", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{})

      DatasetHelpers.add_dataset_to_repo(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:technical, :sourceUrl], intialSourceUrl)
        |> put_in([:technical, :sourceQueryParams], queryParams)

      html =
        render_change(view, :validate, %{
          "form_data" => form_data,
          "_target" => ["form_data", "technical", "sourceQueryParams"]
        })

      assert get_values(html, ".url-form__source-url input") == [updatedSourceUrl]

      where([
        [:intialSourceUrl, :queryParams, :updatedSourceUrl],
        [
          "http://example.com",
          %{"0" => %{"key" => "dog", "value" => "car"}, "1" => %{"key" => "new", "value" => "thing"}},
          "http://example.com?dog=car&new=thing"
        ],
        ["http://example.com?dog=cat&fish=water", %{"0" => %{"key" => "dog", "value" => "cat"}}, "http://example.com?dog=cat"],
        ["http://example.com?dog=cat&fish=water", %{}, "http://example.com"],
        [
          "http://example.com?dog=cat",
          %{"0" => %{"key" => "some space", "value" => "thing=whoa"}},
          "http://example.com?some+space=thing%3Dwhoa"
        ]
      ])
    end

    test "status and time are displayed when source url is tested", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{technical: %{sourceUrl: "123.com"}})

      DatasetHelpers.add_dataset_to_repo(dataset)

      allow(UrlTest.test("123.com", any()), return: %{time: 1_000, status: 200})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_text(html, ".test-status__code") == ""
      assert get_text(html, ".test-status__time") == ""

      render_change(view, :test_url, %{})

      eventually(fn ->
        html = render(view)
        assert get_text(html, ".test-status__code") == "200"
        assert get_text(html, ".test-status__time") == "1000"
      end)
    end

    test "status is displayed with an appropriate class when it is between 200 and 399", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{})

      DatasetHelpers.add_dataset_to_repo(dataset)

      allow(UrlTest.test(dataset.technical.sourceUrl, any()), return: %{time: 1_000, status: 200})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_text(html, ".test-status__code--good") == ""

      render_change(view, :test_url, %{})

      eventually(fn ->
        html = render(view)
        assert get_text(html, ".test-status__code--good") == "200"
      end)
    end

    test "status is displayed with an appropriate class when it is not between 200 and 399", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{})

      DatasetHelpers.add_dataset_to_repo(dataset)

      allow(UrlTest.test(dataset.technical.sourceUrl, any()), return: %{time: 1_000, status: 400})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_text(html, ".test-status__code--bad") == ""

      render_change(view, :test_url, %{})

      eventually(fn ->
        html = render(view)
        assert get_text(html, ".test-status__code--bad") == "400"
        assert get_text(html, ".test-status__code--good") != "400"
      end)
    end

    @tag capture_log: true
    test "status is displayed with an appropriate class when an internal page error occurred", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{})

      DatasetHelpers.add_dataset_to_repo(dataset)

      allow(UrlTest.test(dataset.technical.sourceUrl, any()), exec: fn _ -> raise "derp" end)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_text(html, "#snackbar") == ""

      render_change(view, :test_url, %{})

      eventually(fn ->
        html = render(view)
        assert get_text(html, "#snackbar") == "A page error occurred"
      end)
    end
  end
end
