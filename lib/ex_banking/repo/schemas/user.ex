defmodule ExBanking.User do
  use Memento.Table, attributes: [:username, :currencies]

  alias Ecto.Changeset

  @spec changeset(map()) :: {:ok, map()} | {:error, Changeset.t()}
  def changeset(params) do
    {%__MODULE__{currencies: 0}, %{username: :string, currencies: :integer}}
    |> Changeset.change(params)
    |> Changeset.validate_length(:username, min: 1)
    |> Changeset.validate_number(:currencies, greater_than_or_equal_to: 0)
    |> Changeset.apply_action(:select)
  end
end
