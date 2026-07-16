defmodule AndiWeb.IngestionLiveView.EditIngestionLiveViewTest do
  use ExUnit.Case
  use Placebo

  alias AndiWeb.IngestionLiveView.EditIngestionLiveView
  alias Andi.InputSchemas.Ingestion
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.InputConverter
  alias SmartCity.TestDataGenerator, as: TDG

  import SmartCity.Event, only: [ingestion_update: 0]

  @instance_name Andi.instance_name()

  describe "publish_ingestion/2" do
    setup do
      allow(Andi.Schemas.AuditEvents.log_audit_event(any(), any(), any()), return: %{})
      allow(Ingestions.update_submission_status(any(), any()), return: {:ok, %{}})
      allow(AndiWeb.Endpoint.broadcast_from(any(), any(), any(), any()), return: :ok)
      :ok
    end

    test "sends the unwrapped SmartCity.Ingestion struct to Brook, not the {:ok, _} tuple from the converter" do
      andi_ingestion = %Ingestion{id: "ingestion-1"}
      valid_changeset = %Ecto.Changeset{data: andi_ingestion, valid?: true, errors: []}
      smrt_ingestion = TDG.create_ingestion(%{id: "ingestion-1"})

      allow(Ingestions.get("ingestion-1"), return: andi_ingestion)
      allow(Ingestion.changeset(andi_ingestion, %{}), return: valid_changeset)
      allow(Ingestion.validate(valid_changeset), return: valid_changeset)
      allow(InputConverter.andi_ingestion_to_smrt_ingestion(andi_ingestion), return: {:ok, smrt_ingestion})
      allow(Brook.Event.send(@instance_name, ingestion_update(), :andi, any()), return: :ok)

      assert {:ok, _} = EditIngestionLiveView.publish_ingestion("ingestion-1", :api)

      assert_called Brook.Event.send(@instance_name, ingestion_update(), :andi, smrt_ingestion)
    end

    test "returns an error and does not send a Brook event when conversion to SmartCity.Ingestion fails" do
      andi_ingestion = %Ingestion{id: "ingestion-1"}
      valid_changeset = %Ecto.Changeset{data: andi_ingestion, valid?: true, errors: []}

      allow(Ingestions.get("ingestion-1"), return: andi_ingestion)
      allow(Ingestion.changeset(andi_ingestion, %{}), return: valid_changeset)
      allow(Ingestion.validate(valid_changeset), return: valid_changeset)
      allow(InputConverter.andi_ingestion_to_smrt_ingestion(andi_ingestion), return: {:error, %ArgumentError{}})
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

      assert {:error, _reason} = EditIngestionLiveView.publish_ingestion("ingestion-1", :api)

      refute_called Brook.Event.send(any(), any(), any(), any())
    end
  end
end
