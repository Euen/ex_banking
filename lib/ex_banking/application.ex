defmodule ExBanking.Application do
  @moduledoc false

  use Application
  alias ExBanking.{UserSupervisor}

  @impl true
  def start(_type, _args) do
    children = [
      # Start the User dynamic supervisor
      {UserSupervisor, [name: UserSupervisor]},
      # Start the User process registry
      {Registry, keys: :unique, name: UserRegistry}
    ]

    opts = [strategy: :one_for_one, name: ExBanking.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
