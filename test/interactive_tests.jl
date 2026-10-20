using TestItemRunner

@testmodule InteractiveReplay begin
    function interactive_event_bytes(path)
        key_bytes = Dict(
            "ENTER" => "\r",
            "UP" => "\e[A",
            "DOWN" => "\e[B",
            "LEFT" => "\e[D",
            "RIGHT" => "\e[C",
            "Q" => "q",
        )
        output = IOBuffer()

        for line in eachline(path)
            line = strip(line)
            isempty(line) && continue
            startswith(line, "#") && continue
            if haskey(key_bytes, line)
                write(output, key_bytes[line])
            elseif startswith(line, "TEXT:")
                write(output, line[6:end])
            else
                error("Unknown interactive event: $line")
            end
        end

        return take!(output)
    end

    function interactive_julia_command(project, child, lw_file, session_count)
        julia = Base.julia_cmd()
        return Cmd(vcat(
            julia.exec,
            [
                "--startup-file=no",
                "--history-file=no",
                "--project=$project",
                "--code-coverage=user",
                child,
                lw_file,
                string(session_count),
            ],
        ))
    end

    function run_interactive_replays(event_files, child, lw_file)
        project = dirname(@__DIR__)
        session_count = length(event_files)
        julia_command = interactive_julia_command(project, child, lw_file, session_count)

        if Sys.isunix()
            expect = Sys.which("expect")
            expect === nothing && error("The interactive test requires expect")
            script = joinpath(@__DIR__, "interactive_replay.tcl")
            command = Cmd(vcat([expect, script], event_files, ["--"], julia_command.exec))
            run(command)
        else
            error("Interactive terminal replay is unsupported on this platform")
        end

        return nothing
    end

    function run_interactive_replay(event_file, child, lw_file)
        run_interactive_replays([event_file], child, lw_file)
    end

end

@testitem "interactive menu replay" setup=[InteractiveReplay] begin
    if !Sys.iswindows()
        rm(joinpath(@__DIR__, "temp.lw"); force=true)
        rm(joinpath(@__DIR__, "group1.csv"); force=true)
        rm(joinpath(@__DIR__, "temporary_view.csv"); force=true)
        rm(joinpath(@__DIR__, "test2.lw"); force=true)
        @test !isfile(joinpath(@__DIR__, "temp.lw"))
        @test !isfile(joinpath(@__DIR__, "group1.csv"))
        @test !isfile(joinpath(@__DIR__, "temporary_view.csv"))
        @test !isfile(joinpath(@__DIR__, "test2.lw"))
        InteractiveReplay.run_interactive_replays(
            [
                joinpath(@__DIR__, "inputs", "interactive_events", "menu_navigation.events"),
                joinpath(@__DIR__, "inputs", "interactive_events", "transform_interaction.events"),
                joinpath(@__DIR__, "inputs", "interactive_events", "groups_interaction.events"),
                joinpath(@__DIR__, "inputs", "interactive_events", "views_interaction.events"),
                joinpath(@__DIR__, "inputs", "interactive_events", "coverage.events"),
            ],
            joinpath(@__DIR__, "interactive_child.jl"),
            joinpath(@__DIR__, "inputs", "example.lw"),
        )
        @test isfile(joinpath(@__DIR__, "temp.lw"))
        @test isfile(joinpath(@__DIR__, "group1.csv"))
        @test isfile(joinpath(@__DIR__, "temporary_view.csv"))
        @test isfile(joinpath(@__DIR__, "test2.lw"))
        rm(joinpath(@__DIR__, "temp.lw"); force=true)
        rm(joinpath(@__DIR__, "group1.csv"); force=true)
        rm(joinpath(@__DIR__, "temporary_view.csv"); force=true)
        rm(joinpath(@__DIR__, "test2.lw"); force=true)
    end
end
