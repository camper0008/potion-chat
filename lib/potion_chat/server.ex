defmodule PotionChat.Server do
  def accept(port) do
    {:ok, socket} =
      :gen_tcp.listen(port, [:list, packet: :raw, active: false, reuseaddr: true])

    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    {:ok, pid} =
      Task.Supervisor.start_child(PotionChat.ServerSupervisor, fn -> serve(client, []) end)

    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  @spec serve(term(), term()) :: no_return()
  defp serve(client, rest) do
    packet = read_packet(client)
    {responses, rest} = parse_packet(rest ++ packet)
    write_packet(responses, client)
    serve(client, rest)
  end

  @spec parse_packet([byte()]) :: term()
  defp parse_packet(packet) do
    IO.inspect(PotionChat.Lexer.parse(packet))
    {packet, []}
  end

  @spec parse_packet(term()) :: [byte()]
  defp read_packet(client) do
    {:ok, data} = :gen_tcp.recv(client, 0)
    data
  end

  defp write_packet(responses, client) do
    for response <- responses do
      :gen_tcp.send(client, response)
    end
  end
end
