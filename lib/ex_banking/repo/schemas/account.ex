defmodule ExBanking.Account do
  use Memento.Table,
    attributes: [:id, :username, :currency, :balance],
    index: [:username, :currency],
    type: :ordered_set,
    autoincrement: true

  alias Ecto.Changeset

  @spec changeset(map()) :: {:ok, map} | {:error, Changeset.t()}
  def changeset(params) do
    {%__MODULE__{}, %{username: :string, amount: :float, currency: :string, balance: :float}}
    |> Changeset.change(params)
    |> Changeset.validate_length(:username, min: 1)
    |> Changeset.validate_number(:amount, greater_than: 0)
    |> Changeset.validate_length(:currency, min: 1)
    |> Changeset.validate_number(:balance, greater_than_or_equal_to: 0)
    |> Changeset.apply_action(:select)
  end
end
