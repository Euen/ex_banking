defmodule ExBanking.Users do
  alias ExBanking.{Repo, User}

  @spec create(String.t()) :: {:ok, Memento.Table.record()} | {:error, :wrong_arguments}
  def create(username) do
    with {:ok, user} <- User.changeset(%{username: username, currencies: 0}),
         {:error, _} <- get(user.username),
         {:ok, record} <- Repo.write(user) do
      {:ok, record}
    else
      :ok -> {:error, :user_already_exists}
      _ -> {:error, :wrong_arguments}
    end
  end

  @spec get(String.t()) :: :ok | {:error, {String.t(), :user_does_not_exist}}
  def get(username) do
    case Repo.read(User, username) do
      {:ok, user} when not is_nil(user) -> :ok
      _ -> {:error, {username, :user_does_not_exist}}
    end
  end
end
