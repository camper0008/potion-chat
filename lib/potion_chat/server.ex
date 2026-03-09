defmodule PotionChat.Server do
  def accept(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(PotionChat.ServerSupervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  defp serve(client) do
    read_line(client) |> write_line(client)
    serve(client)
  end

  defp read_line(client) do
    {:ok, data} = :gen_tcp.recv(client, 0)
    IO.puts("got")
    IO.puts(data)
    IO.puts("<eof>")
    data
  end

  defp write_line(line, client) do
    :gen_tcp.send(client, line)
  end
end
