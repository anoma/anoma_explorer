defmodule AnomaExplorer.Settings.AppSetting do
  @moduledoc """
  Schema for application-wide settings stored as key-value pairs.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          key: String.t() | nil,
          value: String.t() | nil,
          description: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "app_settings" do
    field :key, :string
    field :value, :string
    field :description, :string

    timestamps()
  end

  @doc """
  Creates a changeset for an app setting.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :value, :description])
    |> validate_required([:key])
    |> unique_constraint(:key)
  end
end
