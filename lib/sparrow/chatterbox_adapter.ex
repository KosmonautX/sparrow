defmodule ChatterboxAdapter do
  @spec open(String.t(), non_neg_integer(), [any()]) :: {:ok, pid()} | :ignore | {:error, any()}
  def open(uri, port, opts \\ []) do
    try do
      :h2_client.start_link(:https, to_charlist(uri), port, opts)
    catch
      _, reason ->
        {:error, reason}
    end
  end

  @spec close(pid()) :: :ok
  def close(conn) do
    :h2_client.stop(conn)
  end

  @spec post(pid(), String.t(), String.t(), String.t(), String.t()) ::
          {:error, :unable_to_add_stream} | {:ok, any()}
  def post(conn, uri, path, headers, body) do
    case :h2_connection.new_stream(conn) do
      {:error, _code} ->
        {:error, :unable_to_add_stream}

      stream_id ->
        headers = make_headers(:post, uri, path, headers, body)
        :ok = :h2_connection.send_headers(conn, stream_id, headers)
        :ok = :h2_connection.send_body(conn, stream_id, body)
        {:ok, stream_id}
    end
  end

  @spec receive(pid(), any()) :: {:ok, {any(), any()}} | :not_ready
  def receive(conn, stream_id) do
    case :h2_connection.get_response(conn, stream_id) do
      {:ok, {headers, :undefined}} ->
        {:ok, {headers, ""}}

      {:ok, {headers, body}} ->
        {:ok, {headers, Enum.join(body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec ping(pid()) :: :ok
  def ping(conn) do
    :h2_client.send_ping(conn)
  end

  defp make_headers(method, uri, path, headers, body) do
    [
      {":method", String.upcase(Atom.to_string(method))},
      {":path", path},
      {":scheme", "https"},
      {":authority", uri},
      {"content-length", "#{byte_size(body)}"}
    ] ++ headers
  end
end
