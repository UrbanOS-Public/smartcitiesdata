defmodule Andi.Scripts.ResendEvents do
  alias Andi.Schemas.User
  alias SmartCity.UserOrganizationAssociate, as: UOA
  alias Andi.Services.DatasetStore
  import SmartCity.Event

  def build_org_assocs_for_user(user) do
    user_orgs = user.organizations

    user_orgs |> Enum.map(fn org -> %UOA{org_id: org.id, subject_id: user.subject_id, email: user.email} end)
  end

  def resend_user_org_assoc_events() do
    users = User.get_all()

    users
    |> Enum.each(fn user ->
      build_org_assocs_for_user(user)
      |> Enum.each(fn assoc ->
        Brook.Event.send(:andi, user_organization_associate(), :testing, assoc)
      end)
    end)
  end

  def resend_dataset_events() do
    {:ok, datasets} = DatasetStore.get_all()
    datasets |> Enum.map(fn dataset -> Brook.Event.send(:andi, "dataset:update", :testing, dataset) end)
  end
end
