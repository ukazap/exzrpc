defmodule ExZRPC.Codec do
  @type inbound :: list() | :list_routes
  @type outbound :: {:goodrpc, any()} | {:badrpc, any()}

  @spec encode(term()) :: binary()
  def encode({:goodrpc, data}), do: "0" <> :erlang.term_to_binary(data)
  def encode({:badrpc, :invalid_mfa}), do: "1"
  def encode({:badrpc, :invalid_message}), do: "2"
  def encode({:badrpc, reason}), do: "3" <> :erlang.term_to_binary(reason)
  def encode(:list_routes), do: "?"

  def encode([fun_id, args] = term) when is_integer(fun_id) and is_list(args),
    do: "!" <> :erlang.term_to_binary(term)

  @spec decode(binary()) :: term()
  def decode("0" <> bin), do: {:goodrpc, binary_to_term(bin)}
  def decode("1"), do: {:badrpc, :invalid_mfa}
  def decode("2"), do: {:badrpc, :invalid_message}

  def decode("3" <> bin) do
    case binary_to_term(bin) do
      :decode_error -> :decode_error
      reason -> {:badrpc, reason}
    end
  end

  def decode("?"), do: :list_routes

  def decode("!" <> bin) do
    with [fun_id, args] when is_integer(fun_id) and is_list(args) <- binary_to_term(bin) do
      [fun_id, args]
    end
  end

  def decode(_), do: :decode_error

  defp binary_to_term(bin) do
    try do
      :erlang.binary_to_term(bin)
    rescue
      ArgumentError ->
        :decode_error
    end
  end
end
