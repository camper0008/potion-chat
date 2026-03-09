defmodule PotionChat.Lexer do
  @type error_msg() :: {:error, String.t()}
  @type send_msg() :: {:send_msg, String.t()}
  @type action() :: send_msg() | error_msg()

  defmodule Result do
    @enforce_keys [:revert_to, :responses]
    defstruct revert_to: [], responses: []
  end

  defmodule State do
    defmodule HeaderKeyword do
      @enforce_keys :result
      defstruct [:result, keyword: []]
    end

    defmodule HeaderPacketSize do
      @enforce_keys :result
      defstruct [:result, packet_size: []]
    end

    defmodule Content do
      @enforce_keys [:packet_size, :result]
      defstruct [:packet_size, :result, content: []]
    end
  end

  @spec parse([]) :: %Result{}
  @spec parse([byte()]) :: %Result{}
  def parse(input) do
    parse(
      input,
      %State.HeaderKeyword{result: %Result{revert_to: input, responses: []}}
    )
  end

  @spec parse([], %State.HeaderKeyword{} | %State.HeaderPacketSize{} | %State.Content{}) ::
          %Result{}
  defp parse([], state) do
    state.result
  end

  @spec parse(nonempty_list(byte()), %State.HeaderKeyword{}) :: %Result{}
  defp parse([head | tail], state = %State.HeaderKeyword{}) do
    expected = "header\n"

    if String.at(expected, String.length(state.keyword)) != head do
      %Result{
        responses: [
          {:error, "Bad character #{head} following #{state.keyword} - expected 'header\\n'"}
          | state.result
        ],
        revert_to: []
      }
    else
      state = %State.HeaderKeyword{state | keyword: state.keyword <> head}

      if String.length(state.keyword) < String.length(expected) do
        parse(tail, state)
      else
        parse(tail, %State.HeaderPacketSize{result: state.result})
      end
    end
  end

  @spec parse(nonempty_list(byte()), %State.HeaderPacketSize{}) :: %Result{}
  defp parse([head | tail], state = %State.HeaderPacketSize{}) do
    cond do
      Enum.any?(~c"0123456789", fn x -> x == head end) ->
        parse(tail, %State.HeaderPacketSize{state | packet_size: state.packet_size <> head})

      head == ~c"\n" ->
        parse(tail, %State.Content{
          packet_size: Integer.parse(state.packet_size),
          result: state.result
        })

      true ->
        %Result{
          responses: [
            {:error,
             "Bad character #{head} following #{state.packet_size} - expected '0-9' or '.'"}
            | state.result
          ],
          revert_to: []
        }
    end
  end

  @spec parse(nonempty_list(byte()), %State.Content{}) :: %Result{}
  defp parse([head | tail], state = %State.Content{}) do
    if String.length(state.content) == state.packet_size do
      parse(tail, %State.HeaderKeyword{
        result: %Result{
          revert_to: tail,
          responses: [{:send_msg, state.content} | state.result.responses]
        }
      })
    else
      parse(tail, %State.Content{state | content: state.content <> head})
    end
  end
end
