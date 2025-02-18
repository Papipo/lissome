defmodule Lissome.Render do
  alias Lissome.Utils

  @doc """
  Renders a lustre app in server side.

  This function will call the `init_fn` function to get the initial model and then the `view_fn` function to get the initial view.
  """
  def ssr_lustre(module_name, init_fn, view_fn, target_id, flags) do
    model =
      module_name
      |> apply(String.to_atom(init_fn), [{:flags, flags}])
      |> elem(1)

    view =
      apply(module_name, String.to_atom(view_fn), [{:model, model}])

    view
    |> wrap_in_container(target_id)
    |> lustre_to_string()
    |> script_tags(module_name, model)
  end

  @doc """
  Renders a lustre app in client side.

  This function just renders the root container and the script tags necessary to mount the app.
  """
  def render_lustre(module_name, target_id, flags) do
    module_name
    |> wrap_in_container(target_id)
    |> lustre_to_string()
    |> script_tags(module_name, flags)
  end

  defp wrap_in_container(lustre_html, target_id) do
    :lustre@element@html.div(
      [
        :lustre@attribute.id(target_id),
        :lustre@attribute.attribute("phx-update", "ignore")
      ],
      [lustre_html]
    )
  end

  defp script_tags(html, module_name, model) do
    html <>
      """
      <script type="module" src="gleam/#{module_name}.entry.mjs"></script>
      <script type="application/json" id="ls-model">#{Utils.json(model)}</script>
      """
  end

  defp lustre_to_string(lustre_html) do
    :lustre@element.to_string(lustre_html)
  end
end
