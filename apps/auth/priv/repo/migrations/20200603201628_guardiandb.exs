defmodule Auth.Repo.Migrations.CreateGuardianDBTokensTable do
  @moduledoc """
  An ecto migration so token handler can be tested
  """
  use Ecto.Migration

  def change do
    create table(:guardian_tokens, primary_key: false) do
      add(:jti, :string, primary_key: true)
      add(:aud, :string, primary_key: true)
      add(:typ, :string)
      add(:iss, :string)
      add(:sub, :string)
      add(:exp, :bigint)
      add(:jwt, :text)
      add(:claims, :map)
      timestamps()
    end
  end
end
