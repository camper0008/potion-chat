defmodule PotionChat do
  use Application

  @impl true
  def start(_, _) do
    children = [
      {Task.Supervisor, name: PotionChat.ServerSupervisor},
      Supervisor.child_spec({Task, fn -> PotionChat.Server.accept(5555) end}, restart: :permanent)
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
