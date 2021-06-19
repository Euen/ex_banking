defmodule ExBanking.UserSupervisor do
  use DynamicSupervisor

  alias ExBanking.{UserApi, User}
  @table :user_tasks

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, [], opts)
  end

  def init(_arg) do
    create_rate_limiter()
    create_tables!()

    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(username) do
    with {:ok, _user} <- User.changeset(%{username: username}),
         {:ok, _child} <- do_start_child(username) do
      :ok
    else
      {:error, %Ecto.Changeset{}} ->
        {:error, :wrong_arguments}

      {:error, _} ->
        {:error, :user_already_exists}
    end
  end

  defp do_start_child(username) do
    DynamicSupervisor.start_child(
      __MODULE__,
      %{
        id: UserServer,
        start: {UserApi, :start_link, [username]},
        restart: :transient
      }
    )
  end

  # This ETS table is used to limit the cuantity of request a
  # UserServer can handle at the same time
  #
  # Check @max_tasks_per_user in UserApi for modification.
  defp create_rate_limiter do
    :ets.new(@table, [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])
  end

  defp create_tables!() do
    Memento.Table.create!(ExBanking.User)
    Memento.Table.create!(ExBanking.Account)
  end
end
