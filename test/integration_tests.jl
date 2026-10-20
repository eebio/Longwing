@testmodule build begin
    println("build")
    using Pkg
    Pkg.build()
    if !occursin("/.julia/bin", ENV["PATH"])
        path = joinpath(first(DEPOT_PATH), "bin")
        if Sys.iswindows()
            ENV["PATH"] *= ";" * path
        else
            ENV["PATH"] *= ":" * path
        end
    end
end

@testsnippet getshell begin
    println("get shell")
    if Sys.iswindows()
        # Use cmd shell for Windows
        shell = ["cmd", "/C"]
    else
        # Use default shell
        shell = []
    end
end

@testitem "Integration" setup=[environment_path, build, getshell] begin
    println("")
    using JSON
    using StableHashTraits
    using SHA
    using StableHashTraits
    @testset "Template integration" begin
        println("Template integration")
        dir = Base.Filesystem.mktempdir()
        run(`$(shell) lw template --output-path $dir/tmp.xlsx`)
        @test isfile(joinpath(dir, "tmp.xlsx"))
        run(`$(shell) lw template -o $dir/t2.xlsx`)
        @test isfile(joinpath(dir, "t2.xlsx"))
        cd(dir)
        run(`$(shell) lw template`)
        @test isfile("template.xlsx")
        cd(@__DIR__)
    end
    @testset "Translate integration" begin
        println("Translate integration")
        dir = Base.Filesystem.mktempdir()
        run(`$(shell) lw translate $(joinpath("inputs", "example.xlsx")) $(joinpath(dir, "tmp.lw"))`)
        @test isfile(joinpath(dir, "tmp.lw"))
        f = JSON.parsefile(joinpath(dir, "tmp.lw"))
        @test haskey(f["metadata"], "channel_map")
        @test all(haskey(sample["metadata"], "template")
                  for sample in values(f["samples"]))
        f["metadata"]["Manifest.toml"] = ""
        f["metadata"]["Project.toml"] = ""
        f["metadata"]["date_created"] = ""
        f["metadata"]["date_modified"] = ""
        f["metadata"]["versioninfo"] = ""
        f["metadata"]["longwing_version"] = ""
        f["metadata"]["longwing_data_standard_version"] = ""
        for key in keys(f["samples"])
            f["samples"][key]["metadata"]["template"]["data_location"] = ""
        end
        @test bytes2hex(stable_hash(f; version=4)) == "eb5892b4310f04a6759c9cea4df41df81e8af4f847673608e849d514855d51ec"

        run(`$(shell) lw untranslate $(joinpath(dir, "tmp.lw")) $(joinpath(dir, "tmp.xlsx"))`)
        @test isfile(joinpath(dir, "tmp.xlsx"))
    end
    @testset "Untranslate round-trip integration" begin
        println("Untranslate round-trip integration")
        dir = Base.Filesystem.mktempdir()
        first_lw = joinpath(dir, "first.lw")
        reconstructed_xlsx = joinpath(dir, "reconstructed.xlsx")
        second_lw = joinpath(dir, "second.lw")
        input = joinpath("inputs", "untranslate.xlsx")

        run(`$(shell) lw translate $input $first_lw`)
        run(`$(shell) lw untranslate $first_lw $reconstructed_xlsx`)
        run(`$(shell) lw translate $reconstructed_xlsx $second_lw`)

        first_data = JSON.parsefile(first_lw)
        second_data = JSON.parsefile(second_lw)
        for data in (first_data, second_data)
            delete!(data["metadata"], "date_created")
            delete!(data["metadata"], "date_modified")
        end
        @test first_data == second_data
    end
    @testset "Views integration" begin
        println("Views integration")
        # All views
        dir = Base.Filesystem.mktempdir()
        run(`$(shell) lw translate $(joinpath("inputs", "example.xlsx")) $(joinpath(dir, "tmp.lw"))`)
        run(`$(shell) lw views $(joinpath(dir, "tmp.lw")) --output-dir $dir`)
        @test issetequal(readdir(dir),
            ["flowsub.csv", "group1.csv", "group2.csv", "group3.csv",
                "mega.csv", "odsub.csv", "sample.csv", "tmp.lw"])
        rm.(
            joinpath.(dir,
                ["flowsub.csv", "group1.csv", "group2.csv",
                    "group3.csv", "mega.csv", "odsub.csv", "sample.csv"]),
            force=true)
        @test issetequal(readdir(dir), ["tmp.lw"])

        run(`$(shell) lw views $(joinpath(dir, "tmp.lw")) -o $dir`)
        @test issetequal(readdir(dir),
            ["flowsub.csv", "group1.csv", "group2.csv", "group3.csv",
                "mega.csv", "odsub.csv", "sample.csv", "tmp.lw"])

        # Specifying a specific view
        dir = Base.Filesystem.mktempdir()
        run(`$(shell) lw translate $(joinpath("inputs", "example.xlsx")) $(joinpath(dir, "tmp.lw"))`)
        run(`$(shell) lw views $(joinpath(dir, "tmp.lw")) --view mega --output-dir $dir`)
        @test isfile(joinpath(dir, "mega.csv"))
        lw_hash = stable_hash(read(joinpath(dir, "mega.csv"), String); version=4)
        @test bytes2hex(lw_hash) ==
            "9aef713c4e728f5d12064b6198bd04e0708c4b4a58bb9cecaf921f8e1430ec63"

        dir2 = Base.Filesystem.mktempdir()
        run(`$(shell) lw views $(joinpath(dir, "tmp.lw")) -v mega -o $dir2`)
        @test isfile(joinpath(dir2, "mega.csv"))
        lw_hash2 = stable_hash(read(joinpath(dir2, "mega.csv"), String); version=4)
        @test bytes2hex(lw_hash2) ==
            "9aef713c4e728f5d12064b6198bd04e0708c4b4a58bb9cecaf921f8e1430ec63"

        # Specifying multiple views
        dir3 = Base.Filesystem.mktempdir()
        run(`$(shell) lw views $(joinpath(dir, "tmp.lw")) -v flowsub,mega -o $dir3`)
        @test isfile(joinpath(dir3, "mega.csv"))
        @test isfile(joinpath(dir3, "flowsub.csv"))
        # Other views should not be present
        @test !isfile(joinpath(dir3, "group1.csv"))
    end
    @testset "Summarise integration" begin
        println("Summarise integration")

        dir = Base.Filesystem.mktempdir()
        cp(joinpath("inputs", "summarise.lw"), joinpath(dir, "summarise.lw"))
        run(`$(shell) lw summarise $(joinpath(dir, "summarise.lw")) --plot`)
        @test isfile(joinpath(dir, "summarise.lw.pdf"))
        rm(joinpath(dir, "summarise.lw.pdf"), force=true)
        run(`$(shell) lw summarise $(joinpath(dir, "summarise.lw")) -p`)
        @test isfile(joinpath(dir, "summarise.lw.pdf"))

        cp(joinpath("inputs", "small.fcs"), joinpath(dir, "small.fcs"))
        run(`$(shell) lw summarise $(joinpath(dir, "small.fcs"))`)
        @test !isfile(joinpath(dir, "small.fcs.pdf"))
        @test !isfile(joinpath(dir, "small.fcs.csv"))
        run(`$(shell) lw summarise $(joinpath(dir, "small.fcs")) --plot --csv`)
        @test isfile(joinpath(dir, "small.fcs.pdf"))
        @test isfile(joinpath(dir, "small.fcs.csv"))

        cp(joinpath("inputs", "spectramax-summarise.txt"), joinpath(dir, "spectramax-summarise.txt"))
        run(`$(shell) lw summarise $(joinpath(dir, "spectramax-summarise.txt")) --type spectramax`)
        @test !isfile(joinpath(dir, "spectramax-summarise.txt.pdf"))
        run(`$(shell) lw summarise $(joinpath(dir, "spectramax-summarise.txt")) -t spectramax --plot --csv`)
        @test isfile(joinpath(dir, "spectramax-summarise.txt.pdf"))
        @test isfile(joinpath(dir, "spectramax-summarise.txt_600.csv"))
        @test isfile(joinpath(dir, "spectramax-summarise.txt_700.csv"))
        @test isfile(joinpath(dir, "spectramax-summarise.txt_535_485.csv"))

        cp(joinpath("inputs", "biotek-summarise.csv"), joinpath(dir, "biotek-summarise.csv"))
        run(`$(shell) lw summarise $(joinpath(dir, "biotek-summarise.csv")) --type biotek`)
        @test !isfile(joinpath(dir, "biotek-summarise.csv.pdf"))
        run(`$(shell) lw summarise $(joinpath(dir, "biotek-summarise.csv")) -t biotek -p -c`)
        @test isfile(joinpath(dir, "biotek-summarise.csv.pdf"))
        @test isfile(joinpath(dir, "biotek-summarise.csv_OD_600.csv"))
        @test isfile(joinpath(dir, "biotek-summarise.csv_OD_700.csv"))
        @test isfile(joinpath(dir, "biotek-summarise.csv_GFP_485_530.csv"))

        cp(joinpath("inputs", "tecan-summarise.xlsx"), joinpath(dir, "tecan-summarise.xlsx"))
        run(`$(shell) lw summarise $(joinpath(dir, "tecan-summarise.xlsx")) --type tecan`)
        @test !isfile(joinpath(dir, "tecan-summarise.xlsx.pdf"))
        run(`$(shell) lw summarise $(joinpath(dir, "tecan-summarise.xlsx")) -t tecan -p --csv`)
        @test isfile(joinpath(dir, "tecan-summarise.xlsx.pdf"))
        @test isfile(joinpath(dir, "tecan-summarise.xlsx_OD_600.csv"))
        @test isfile(joinpath(dir, "tecan-summarise.xlsx_OD_700.csv"))
        @test isfile(joinpath(dir, "tecan-summarise.xlsx_GFP.csv"))

        cp(joinpath("inputs", "bmg-summarise.csv"), joinpath(dir, "bmg-summarise.csv"))
        run(`$(shell) lw summarise $(joinpath(dir, "bmg-summarise.csv")) --type bmg`)
        @test !isfile(joinpath(dir, "bmg-summarise.csv.pdf"))
        run(`$(shell) lw summarise $(joinpath(dir, "bmg-summarise.csv")) -t bmg -p --csv`)
        @test isfile(joinpath(dir, "bmg-summarise.csv.pdf"))
        @test isfile(joinpath(dir, "bmg-summarise.csv_ABS_600_0_nm.csv"))
        @test isfile(joinpath(dir, "bmg-summarise.csv_ABS_700_0_nm.csv"))
        @test isfile(joinpath(dir, "bmg-summarise.csv_FI_YFP_pAN1717.csv"))

        cp(joinpath("inputs", "pr_folder"), joinpath(dir, "pr_folder"))
        run(`$(shell) lw summarise $(joinpath(dir, "pr_folder"))`)
        @test !isfile(joinpath(dir, "pr_folder.pdf"))
        run(`$(shell) lw summarise $(joinpath(dir, "pr_folder")) -p -c`)
        @test isfile(joinpath(dir, "pr_folder.pdf"))
        @test isfile(joinpath(dir, "pr_folder_OD.csv"))
        @test isfile(joinpath(dir, "pr_folder_flo.csv"))
    end
end

#The integration tests won't track code coverage, so we repeat them with the Julia interface here
@testitem "Integration coverage" setup=[environment_path] begin
    println("Integration coverage")
    dir = Base.Filesystem.mktempdir()
    template(output_path=joinpath(dir, "tmp.xlsx"))
    translate(joinpath("inputs", "example.xlsx"), joinpath(dir, "tmp.lw"))
    views(joinpath(dir, "tmp.lw"); output_dir=dir)
    views(joinpath(dir, "tmp.lw"); view="mega", output_dir=dir)
    views(joinpath(dir, "tmp.lw"); view="flowsub,mega", output_dir=dir)
    translate(joinpath("inputs", "summarise.xlsx"), joinpath(dir, "summarise.lw"))
    untranslate(joinpath(dir, "summarise.lw"), joinpath(dir, "reconstructed.xlsx"))
    summarise(joinpath(dir, "summarise.lw"); plot=true)
    cp(joinpath("inputs", "small.fcs"), joinpath(dir, "small.fcs"))
    cp(joinpath("inputs", "spectramax-summarise.txt"), joinpath(dir, "spectramax-summarise.txt"))
    cp(joinpath("inputs", "biotek-summarise.csv"), joinpath(dir, "biotek-summarise.csv"))
    cp(joinpath("inputs", "tecan-summarise.xlsx"), joinpath(dir, "tecan-summarise.xlsx"))
    cp(joinpath("inputs", "bmg-summarise.csv"), joinpath(dir, "bmg-summarise.csv"))
    cp(joinpath("inputs", "pr_folder"), joinpath(dir, "pr_folder"))
    summarise(joinpath(dir, "small.fcs"); plot=true)
    summarise(joinpath(dir, "spectramax-summarise.txt"); type="spectramax", plot=true)
    summarise(joinpath(dir, "biotek-summarise.csv"); type="biotek", plot=true)
    summarise(joinpath(dir, "tecan-summarise.xlsx"); type="tecan", plot=true)
    summarise(joinpath(dir, "bmg-summarise.csv"); type="bmg", plot=true)
    summarise(joinpath(dir, "pr_folder"); plot=true)
end
