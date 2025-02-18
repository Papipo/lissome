defmodule Mix.Tasks.Compile.GleamJs do
  use Mix.Task

  @shortdoc "Compile Gleam source files to JavaScript and then bundle them using esbuild binary"
  @shell Mix.shell()

  @moduledoc """
  #{@shortdoc}

  Built files are placed in the `priv/static/gleam` folder.

  ## Examples:

      # Compile Gleam to Javascript in a Mix project
      # and bundle with esbuild in minified mode
      mix compile.gleam_js --minify

  Gleam compilation will not occur where no `.gleam` files are located.

  To use this taks, first make sure you have the Gleam to Erlang compiler `gleam` from `mix_gleam` in your compilers list, then include this task in your project's `mix.exs` with, e.g.:

      def project do
        [
          compilers: [:gleam, :gleam_js] ++ Mix.compilers(),
        ]
      end

  Credit goes to the [mix_gleam](https://github.com/gleam-lang/mix_gleam) project, on which this compiler has been modeled.
  """

  @switches [
    minify: :boolean
  ]

  @impl true
  def run(args) do
    MixGleam.IO.debug_info("Javascript compilation start")

    Mix.Project.get!()

    case OptionParser.parse(args, switches: @switches) do
      {options, _, _} ->
        gleam? =
          File.exists?("src") and Enum.any?(File.ls!("src"), &String.ends_with?(&1, ".gleam"))

        if gleam? do
          config = Keyword.merge(options, Mix.Project.config())

          app =
            try do
              Keyword.get_lazy(config, :app, fn -> elem(config[:lock], 1) end)
            rescue
              _ -> raise MixGleam.Error, message: "Unable to find app name"
            end

          app_build_dir =
            Path.join([Mix.Project.build_path(), "lib/#{app}"])

          compiled_files = compile(app, app_build_dir)

          bundle(compiled_files, config, app_build_dir)
        end
    end

    MixGleam.IO.debug_info("Javascript compilation end")
  end

  defp compile(app, app_build_dir) do
    # A minimal `gleam.toml` config with a project name is required by
    # `gleam build`.
    #
    # We reuse the generated by a previous erlang compilation if any,
    # otherwise we create one here.

    package =
      cond do
        File.regular?("gleam.toml") ->
          "."

        File.regular?(Path.join(app_build_dir, "gleam.toml")) ->
          app_build_dir

        true ->
          app_build_dir
          |> Path.join("gleam.toml")
          |> File.write!(~s(name = "#{app}"))

          ["src", "test"]
          |> Enum.each(fn dir ->
            src = Path.absname(dir)
            dest = Path.join(app_build_dir, dir)
            File.rm_rf!(dest)

            if File.ln_s(src, dest) != :ok do
              File.cp_r!(src, dest)
            end
          end)

          app_build_dir
      end

    out = "build/dev/javascript/#{app}"

    cmd =
      "gleam build --target javascript"

    @shell.info(~s(Compiling #{app} gleam frontend to javascript))
    MixGleam.IO.debug_info("Compiler Command", cmd)
    compiled? = @shell.cmd(cmd, cd: package) === 0

    if compiled? do
      package
      |> Path.join(out)
      |> File.ls!()
      |> Enum.filter(&(String.ends_with?(&1, ".mjs") and &1 != "gleam.mjs"))
      |> Enum.map(&Path.join([package, out, &1]))
    else
      raise MixGleam.Error, message: "JS Compilation failed"
    end
  end

  defp bundle(compiled_files, config, app_build_dir) do
    out = Path.join(app_build_dir, "priv/static/gleam")

    File.mkdir_p!(out)

    esbuild = Esbuild.bin_path()

    args =
      compiled_files
      |> prepend_minify(config[:minify])
      |> Enum.concat(~w(--bundle --format=esm --outdir=#{out}))

    bundled? =
      esbuild
      |> System.cmd(args)
      |> elem(1) === 0

    if bundled? do
      Enum.each(compiled_files, fn file ->
        base_name = Path.basename(file, ".mjs")
        entry = build_entry(base_name)
        File.write!(Path.join(out, "#{base_name}.entry.mjs"), entry)
      end)

      :ok
    else
      raise MixGleam.Error,
        message:
          "JS Bundling failed. Check if you have esbuild binary in your Elixir's build directory."
    end
  end

  defp build_entry(base_name) do
    "import { main } from './#{base_name}.js'; main?.();"
  end

  defp prepend_minify(args, minify) do
    if minify,
      do: ["--minify" | args],
      else: args
  end
end
