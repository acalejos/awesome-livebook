Mix.install([
  {:jason, "~> 1.4"},
  {:req, "~> 0.5"}
])

req =
  Req.new(
    base_url: "https://api.github.com/repos/:owner/:repo",
    headers: %{
      "accept" => "application/vnd.github.text-match+json",
      "x-github-api-version" => "2022-11-28"
    },
    auth: {:bearer, System.fetch_env!("GITHUB_TOKEN")}
  )

%{"description" => description} =
  details =
  "awesome_livebook.json"
  |> File.read!()
  |> Jason.decode!()

sections =
  for %{"content" => contents, "name" => name} <- details["sections"],
      %{"url" => url} = entry <- contents,
      entry = Map.put(entry, "section", name) do
    with %URI{host: "github.com", path: p} <- URI.parse(url),
         [owner | [repo | _]] <- String.split(p, "/", trim: true),
         {:ok, %Req.Response{status: 200, body: body}} <-
           Req.get(req, path_params: [owner: owner, repo: repo]) do
      entry =
        Map.put(
          entry,
          "type",
          if(owner in ["livebook-dev", "elixir-lang"], do: "official", else: "community")
        )

      case body do
        %{"description" => description} when not is_nil(description) ->
          Map.put(entry, "description", description)

        _ ->
          entry
      end
    else
      _ ->
        entry
    end
  end
  |> Enum.sort_by(&Map.get(&1, "name"))
  |> Enum.group_by(&Map.get(&1, "section"))

readme = EEx.eval_file("README.eex", assigns: [sections: sections, description: description])

File.write!("README.md", readme)
