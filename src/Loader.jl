"""
Genie code loading functionality -- loading and managing app-wide components like configs, models, initializers, etc.
"""
module Loader

import Logging
import REPL, REPL.Terminals
import Revise
import Genie


### PRIVATE ###


"""
    bootstrap(context::Union{Module,Nothing} = nothing) :: Nothing

Kickstarts the loading of a Genie app by loading the environment settings.
"""
function bootstrap(context::Union{Module,Nothing} = default_context(context)) :: Nothing
  ENV_FILE_NAME = "env.jl"
  GLOBAL_ENV_FILE_NAME = "global.jl"

  if haskey(ENV, "GENIE_ENV")
    Genie.config.app_env = ENV["GENIE_ENV"]
    isfile(joinpath(Genie.config.path_env, GLOBAL_ENV_FILE_NAME)) && Base.include(context, joinpath(Genie.config.path_env, GLOBAL_ENV_FILE_NAME))
    isfile(joinpath(Genie.config.path_env, ENV["GENIE_ENV"] * ".jl")) && Base.include(context, joinpath(Genie.config.path_env, ENV["GENIE_ENV"] * ".jl"))
    Genie.config.app_env = ENV["GENIE_ENV"] # ENV might have changed
  end

  haskey(ENV, "PORT") && (! isempty(ENV["PORT"])) && (Genie.config.server_port = parse(Int, ENV["PORT"]))
  haskey(ENV, "WSPORT") && (! isempty(ENV["WSPORT"])) && (Genie.config.websockets_port = parse(Int, ENV["WSPORT"]))
  haskey(ENV, "HOST") && (! isempty(ENV["HOST"])) && (Genie.config.server_host = ENV["HOST"])
  haskey(ENV, "HOST") || (ENV["HOST"] = Genie.config.server_host)

  printstyled("""


   ██████╗ ███████╗███╗   ██╗██╗███████╗    ███████╗
  ██╔════╝ ██╔════╝████╗  ██║██║██╔════╝    ██╔════╝
  ██║  ███╗█████╗  ██╔██╗ ██║██║█████╗      ███████╗
  ██║   ██║██╔══╝  ██║╚██╗██║██║██╔══╝      ╚════██║
  ╚██████╔╝███████╗██║ ╚████║██║███████╗    ███████║
   ╚═════╝ ╚══════╝╚═╝  ╚═══╝╚═╝╚══════╝    ╚══════╝

  """, color = :light_black, bold = true)

  printstyled("| Website  https://genieframework.com\n", color = :light_black, bold = true)
  printstyled("| GitHub   https://github.com/genieframework\n", color = :light_black, bold = true)
  printstyled("| Docs     https://genieframework.com/docs\n", color = :light_black, bold = true)
  printstyled("| Discord  https://discord.com/invite/9zyZbD6J7H\n", color = :light_black, bold = true)
  printstyled("| Twitter  https://twitter.com/essenciary\n\n", color = :light_black, bold = true)
  printstyled("Active env: $(ENV["GENIE_ENV"] |> uppercase)\n\n", color = :light_blue, bold = true)

  nothing
end


"""
    load_libs(root_dir::String = Genie.config.path_lib) :: Nothing

Recursively includes files from `lib/` and subfolders.
The `lib/` folder, if present, is designed to host user code in the form of .jl files.
"""
function load_libs(root_dir::String = Genie.config.path_lib; context::Union{Module,Nothing} = nothing) :: Nothing
  autoload(root_dir; context)
end


"""
    load_resources(root_dir::String = Genie.config.path_resources) :: Nothing

Automatically recursively includes files from `resources/` and subfolders.
"""
function load_resources(root_dir::String = Genie.config.path_resources;
                        context::Union{Module,Nothing} = nothing) :: Nothing
  autoload(root_dir; context, skipdirs = ["views"])
end


"""
    load_helpers(root_dir::String = Genie.config.path_helpers) :: Nothing

Automatically recursively includes files from `helpers/` and subfolders.
"""
function load_helpers(root_dir::String = Genie.config.path_helpers; context::Union{Module,Nothing} = nothing) :: Nothing
  autoload(root_dir; context)
end


"""
    load_initializers(root_dir::String = Genie.config.path_config; context::Union{Module,Nothing} = nothing) :: Nothing

Automatically recursively includes files from `initializers/` and subfolders.
"""
function load_initializers(root_dir::String = Genie.config.path_initializers; context::Union{Module,Nothing} = nothing) :: Nothing
  autoload(root_dir; context)
end


"""
    load_plugins(root_dir::String = Genie.config.path_plugins; context::Union{Module,Nothing} = nothing) :: Nothing

Automatically recursively includes files from `plugins/` and subfolders.
"""
function load_plugins(root_dir::String = Genie.config.path_plugins; context::Union{Module,Nothing} = nothing) :: Nothing
  autoload(root_dir; context)
end


"""
    load_routes(routes_file::String = Genie.ROUTES_FILE_NAME; context::Union{Module,Nothing} = nothing) :: Nothing

Loads the routes file.
"""
function load_routes(routes_file::String = Genie.ROUTES_FILE_NAME; context::Union{Module,Nothing} = nothing) :: Nothing
  isfile(routes_file) && Revise.includet(default_context(context), routes_file)

  nothing
end


"""
    autoload

Automatically and recursively includes files from the indicated `root_dir` into the indicated `context` module,
skipping directories from `dir`.
The files are set up with `Revise` to be automatically reloaded when changed (in dev environment).
"""
function autoload(root_dir::String = Genie.config.path_lib;
                  context::Union{Module,Nothing} = nothing,
                  skipdirs::Vector{String} = String[]) :: Nothing
  isdir(root_dir) || return nothing

  for i in readdir(root_dir)
    fi = joinpath(root_dir, i)
    endswith(fi, ".jl") && Revise.includet(default_context(context), fi)
  end

  for (root, dirs, files) in walkdir(root_dir)
    for dir in dirs
      in(dir, skipdirs) && continue

      p = joinpath(root, dir)
      for i in readdir(p)
        fi = joinpath(p, i)
        endswith(fi, ".jl") && Revise.includet(default_context(context), fi)
      end
    end
  end

  nothing
end


function autoload(dirs::Vector{String}; kwargs...)
  for d in dirs
    autoload(d; kwargs...)
  end
end


function autoload(dirs...; kwargs...)
  autoload([dirs...]; kwargs...)
end


"""
    load(; context::Union{Module,Nothing} = nothing) :: Nothing

Main entry point to loading a Genie app.
"""
function load(; context::Union{Module,Nothing} = nothing) :: Nothing
  context = default_context(context)

  Genie.Configuration.isdev() && Core.eval(context, :(__revise_mode__ = :eval))

  bootstrap(context)

  t = Terminals.TTYTerminal("", stdin, stdout, stderr)

  for i in Genie.config.autoload
    f = getproperty(@__MODULE__, Symbol("load_$i"))
    Genie.Repl.replprint(string(i), t; prefix = "Loading ", clearline = 3, sleep_time = 0.0)
    Base.@invokelatest f(; context)
    Genie.Repl.replprint("$i ✅", t; prefix = "Loading ", clearline = 3, color = :green, sleep_time = 0.1)
  end

  Genie.Repl.replprint("\nReady! \n", t; clearline = 1, color = :green, bold = :true)
  println()

  nothing
end


"""
    default_context(context::Union{Module,Nothing})

Sets the module in which the code is loaded (the app's module)
"""
function default_context(context::Union{Module,Nothing} = nothing)
  try
    context === nothing ? Main.UserApp : context
  catch ex
    @error ex
    @__MODULE__
  end
end

end