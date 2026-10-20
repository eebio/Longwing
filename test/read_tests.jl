# Test read_longwing function
@testmodule MockLongwing begin
    println("MockLongwing")
    using Longwing
    mock_data = """
{
    "samples": {
        "plate_01_a1": {
            "values": {
                "FL1_A": [
                    54.0,
                    143.0,
                    25.0,
                    71.0
                ],
                "SSC_H": [
                    534.0,
                    645.0,
                    346.0,
                    1254.0
                ],
                "FSC_H": [
                    634.0,
                    965.0,
                    643.0,
                    1015.0
                ]
            },
            "type": "population",
            "metadata": {
                "FL1_A": {
                    "range": "1024",
                    "ex_pow": null,
                    "filter": null,
                    "det_volt": null,
                    "amp_type": "0,0",
                    "ex_wav": null,
                    "amp_gain": null,
                    "name_s": null,
                    "name": "FL1-A",
                    "det_type": null,
                    "perc_em": null,
                    "longwing_well": "a1",
                    "raw_metadata": {}
                },
                "SSC_H": {
                    "range": "1024",
                    "ex_pow": null,
                    "filter": null,
                    "det_volt": null,
                    "amp_type": "2,0.01",
                    "ex_wav": null,
                    "amp_gain": null,
                    "name_s": "SSC-H",
                    "name": "SSC-H",
                    "det_type": null,
                    "perc_em": null,
                    "longwing_well": "a1",
                    "raw_metadata": {}
                },
                "FSC_H": {
                    "range": "1024",
                    "ex_pow": null,
                    "filter": null,
                    "det_volt": null,
                    "amp_type": "0,0",
                    "ex_wav": null,
                    "amp_gain": null,
                    "name_s": "FSC-H",
                    "name": "FSC-H",
                    "det_type": null,
                    "perc_em": null,
                    "longwing_well": "a1",
                    "raw_metadata": {}
                }
            }
        },
        "plate_01_a2": {
            "values": {
                "FL1_A": [
                    0.0,
                    143.0,
                    0.0,
                    61.0
                ],
                "SSC_H": [
                    280.0,
                    735.0,
                    128.0,
                    1023.0
                ],
                "FSC_H": [
                    628.0,
                    1023.0,
                    373.0,
                    1023.0
                ]
            },
            "type": "population",
            "metadata": {
                "FL1_A": {
                    "range": "1024",
                    "ex_pow": null,
                    "filter": null,
                    "det_volt": null,
                    "amp_type": "0,0",
                    "ex_wav": null,
                    "amp_gain": null,
                    "name_s": null,
                    "name": "FL1-A",
                    "det_type": null,
                    "perc_em": null,
                    "longwing_well": "a2",
                    "raw_metadata": {}
                },
                "SSC_H": {
                    "range": "1024",
                    "ex_pow": null,
                    "filter": null,
                    "det_volt": null,
                    "amp_type": "2,0.01",
                    "ex_wav": null,
                    "amp_gain": null,
                    "name_s": "SSC-H",
                    "name": "SSC-H",
                    "det_type": null,
                    "perc_em": null,
                    "longwing_well": "a2",
                    "raw_metadata": {}
                },
                "FSC_H": {
                    "range": "1024",
                    "ex_pow": null,
                    "filter": null,
                    "det_volt": null,
                    "amp_type": "0,0",
                    "ex_wav": null,
                    "amp_gain": null,
                    "name_s": "FSC-H",
                    "name": "FSC-H",
                    "det_type": null,
                    "perc_em": null,
                    "longwing_well": "a2",
                    "raw_metadata": {}
                }
            }
        }
    },
    "groups": {
        "plate_01": {
            "type": "physical",
            "sample_IDs": [
                "plate_01_a1",
                "plate_01_a2"
            ],
            "metadata": {
                "autodefined": "true"
            }
        }
    },
    "transformations": {
        "flow_cyt": {
            "equation": "1"
        }
    },
    "views": {
        "flow_cy": {
            "data": [
                "flow_cyt"
            ]
        }
    },
    "metadata": {
"date_created": "2026-05-04T15:12:08.285",
"date_modified": "2026-05-04T15:12:08.285",
"Project.toml": "Project Longwing v0.1.0\\nStatus `~/.julia/dev/Longwing/Project.toml`\\n  [336ed68f] CSV v0.10.16\\n  [861a8166] Combinatorics v1.1.0\\n  [863f3e99] Comonicon v1.0.8\\n  ...\\n  [ade2ca70] Dates v1.11.0\\n  [b77e0a4c] InteractiveUtils v1.11.0\\n  [44cfe95a] Pkg v1.12.1\\n  [de0858da] Printf v1.11.0\\nInfo Packages marked with ⌃ and ⌅ have new versions available. Those with ⌃ may be upgradable, but those with ⌅ are restricted by compatibility constraints from upgrading. To see why use `status --outdated`\\n",
"longwing_version": "0.1.0",
"versioninfo": "Julia Version 1.12.3\\nCommit 966d0af0fdf (2025-12-15 11:20 UTC)\\nBuild Info:\\n  Official https://julialang.org release\\nPlatform Info:\\n  OS: macOS (arm64-apple-darwin24.0.0)\\n  CPU: 14 × Apple M4 Pro\\n  WORD_SIZE: 64\\n  LLVM: libLLVM-18.1.7 (ORCJIT, apple-m4)\\n  GC: Built with stock GC\\nThreads: 1 default, 1 interactive, 1 GC (on 10 virtual cores)\\nEnvironment:\\n  JULIA_EDITOR = code\\n  JULIA_VSCODE_REPL = 1\\n",
"Manifest.toml": "Project Longwing v0.1.0\\nStatus `~/.julia/dev/Longwing/Manifest.toml`\\n⌃ [47edcb42] ADTypes v1.21.0\\n  [621f4979] AbstractFFTs v1.5.0\\n  [1520ce14] AbstractTrees v0.4.5\\n  [7d9f7c33] Accessors v0.1.44\\n...\\n  [8e850ede] nghttp2_jll v1.64.0+1\\n  [3f19e933] p7zip_jll v17.7.0+0\\nInfo Packages marked with ⌃ and ⌅ have new versions available. Those with ⌃ may be upgradable, but those with ⌅ are restricted by compatibility constraints from upgrading. To see why use `status --outdated -m`\\n",
"longwing_data_standard_version": "0.1.0",
"description": ""
    }
}

"""

    # Write mock data to a temporary file
    temp_file = joinpath(Base.Filesystem.mktempdir(), "temp_mock_data.lw")
    open(temp_file, "w") do f
        write(f, mock_data)
    end
end

@testitem "read_longwing tests" setup=[MockLongwing] begin
    println("read_longwing tests")
    lw = read_longwing(MockLongwing.temp_file)
    @test issetequal(lw.samples.name,
        ["plate_01_a1.FL1_A", "plate_01_a1.SSC_H", "plate_01_a1.FSC_H",
            "plate_01_a2.FL1_A", "plate_01_a2.SSC_H", "plate_01_a2.FSC_H"])
    @test issetequal(
        lw.samples.channel, ["FL1_A", "SSC_H", "FSC_H", "FL1_A", "SSC_H", "FSC_H"])
    @test issetequal(lw.samples.type,
        ["population", "population", "population",
            "population", "population", "population"])
    @test issetequal(lw.samples.values,
        [
            [54.0, 143.0, 25.0, 71.0],
            [534.0, 645.0, 346.0, 1254.0],
            [634.0, 965.0, 643.0, 1015.0],
            [0.0, 143.0, 0.0, 61.0],
            [280.0, 735.0, 128.0, 1023.0],
            [628.0, 1023.0, 373.0, 1023.0]
        ])
    @test lw.samples.metadata[lw.samples.name .== "plate_01_a2.FL1_A"][1] ==
        Dict{String,Any}(
        "amp_type" => "0,0", "filter" => nothing, "det_type" => nothing,
        "name" => "FL1-A", "range" => "1024", "det_volt" => nothing,
        "amp_gain" => nothing, "name_s" => nothing,
        "perc_em" => nothing, "ex_wav" => nothing, "ex_pow" => nothing, "longwing_well" => "a2", "raw_metadata" => Dict())
    @test lw.samples.metadata[lw.samples.name .== "plate_01_a2.FSC_H"][1] ==
        Dict{String,Any}(
        "amp_type" => "0,0", "filter" => nothing, "det_type" => nothing,
        "name" => "FSC-H", "range" => "1024", "det_volt" => nothing,
        "amp_gain" => nothing, "name_s" => "FSC-H",
        "perc_em" => nothing, "ex_wav" => nothing, "ex_pow" => nothing, "longwing_well" => "a2", "raw_metadata" => Dict())
    for i in 1:6
        @test issetequal(keys(lw.samples.metadata[i]),
            ["range", "ex_pow", "filter", "det_volt", "amp_type", "ex_wav",
                "amp_gain", "name_s", "name", "det_type", "perc_em", "longwing_well", "raw_metadata"])
    end
    @test issetequal(lw.groups.group, ["plate_01"])
    @test issetequal(lw.groups.sample_IDs, [["plate_01_a1", "plate_01_a2"]])
    @test issetequal(lw.groups.metadata, [Dict("autodefined" => "true")])
    @test lw.transformations ==
        Dict("flow_cyt" => Dict("equation" => "1"))
    @test lw.views == Dict("flow_cy" => Dict("data" => ["flow_cyt"]))
end

# Test index_between_vals
@testitem "index_between_vals" begin
    println("index_between_vals")
    using DataFrames

    # Sample data for testing
    df = DataFrame(A=1:10, B=11:20)

    result = Longwing.index_between_vals(df[!, :A]; minv=3, maxv=8)
    @test result == (3, 8)

    result = Longwing.index_between_vals(df[!, :A]; minv=5, maxv=10)
    @test result == (5, 10)

    result = Longwing.index_between_vals(df[!, :B]; minv=0, maxv=15)
    @test result == (1, 5)

    result = Longwing.index_between_vals(df[!, :A]; minv=2.5, maxv=13.5)
    @test result == (3, 10)

    result = Longwing.index_between_vals(df[!, :B]; minv=2.5, maxv=13.5)
    @test result == (1, 3)

    result = Longwing.index_between_vals(df[!, :A])
    @test result == (1, 10)
end

# Test between_times
@testitem "between_times" begin
    println("between_times")
    using DataFrames

    # Sample data for testing
    df = DataFrame(A=1:10, B=11:20)
    time_col = DataFrame(Time=[518000, 1118000, 1718000, 2318000, 2918000,
        3518000, 4118000, 4718000, 5318000, 5400000])

    result = Longwing.between_times(df, time_col; mint=0, maxt=0)
    @test isequal(result, DataFrame(A=fill(missing, 10), B=fill(missing, 10)))

    result = Longwing.between_times(df, time_col; mint=1e-11, maxt=3e-11)
    @test isequal(result, DataFrame(A=fill(missing, 10), B=fill(missing, 10)))

    result = Longwing.between_times(df, time_col; mint=9, maxt=15)
    @test isequal(result, DataFrame(A=fill(missing, 10), B=fill(missing, 10)))

    result = Longwing.between_times(df, time_col; mint=0, maxt=50)
    @test isequal(result, DataFrame(A=[1:5..., fill(missing, 5)...], B=[11:15..., fill(missing, 5)...]))

    result = Longwing.between_times(df, time_col; mint=90, maxt=90)
    @test isequal(result, DataFrame(A=[fill(missing, 9)..., 10], B=[fill(missing, 9)..., 20]))
end

# Test between
@testitem "between" begin
    println("between")
    using DataFrames

    # Sample data for testing
    df = DataFrame(A=1:10, B=11:20)

    # between(df; min_value, max_value)
    result = Longwing.between(df; min_value=7, max_value=15)
    @test isequal(result, DataFrame(A=[fill(missing, 6)..., 7:10...], B=[11:15..., fill(missing, 5)...]))
    result = Longwing.between(df; min_value=0, max_value=0.5)
    @test isequal(result, DataFrame(A=fill(missing, 10), B=fill(missing, 10)))
    result = Longwing.between(df; min_value=10, max_value=20)
    @test isequal(result, DataFrame(A=[fill(missing, 9)..., 10], B=11:20))
    result = Longwing.between(df; min_value=0, max_value=50)
    @test isequal(result, DataFrame(A=1:10, B=11:20))

    # between(df, range_col, min_value, max_value)
    result = Longwing.between(df, df[:, :A]; min_value=7, max_value=15)
    @test isequal(result, DataFrame(A=[fill(missing, 6)..., 7:10...], B=[
        fill(missing, 6)..., 17:20...]))
    result = Longwing.between(df, df[:, [:A]]; min_value=0, max_value=0.5)
    @test isequal(result, DataFrame(A=fill(missing, 10), B=fill(missing, 10)))
    result = Longwing.between(df, df[:, :B]; min_value=10, max_value=20)
    @test isequal(result, DataFrame(A=1:10, B=11:20))
    result = Longwing.between(df, df[:, [:B]]; min_value=0, max_value=50)
    @test isequal(result, DataFrame(A=1:10, B=11:20))
    result = Longwing.between(df, df[:, :B]; min_value=0, max_value=5)
    @test isequal(result, DataFrame(A=fill(missing, 10), B=fill(missing, 10)))

    # Sample data for testing
    df = DataFrame(A=1:10, B=11:20)
    range_df = DataFrame(A=5:14, B=9:18)
    result = Longwing.between(df, range_df; min_value=7, max_value=15)
    @test isequal(result, DataFrame(A=[fill(missing, 2)..., 3:10...], B=[
        11:17..., fill(missing, 3)...]))
    result = Longwing.between(df, range_df; min_value=3, max_value=4)
    @test isequal(result, DataFrame(A=fill(missing, 10), B=fill(missing, 10)))
    result = Longwing.between(df, range_df; min_value=15, max_value=50)
    @test isequal(result, DataFrame(A=fill(missing, 10), B=
    [fill(missing, 6)..., 17:20...]))
end

# Test at_time
@testitem "at_time" begin
    println("at_time")
    using DataFrames

    # Sample data for testing
    df = DataFrame(A=1:10, B=11:20)
    time_col = DataFrame(Time=[518000, 1118000, 1718000, 2318000, 2918000,
        3518000, 4118000, 4718000, 5318000, 5918000])

    # Recasts into DataFrame again as this removes the Row indexes (which are used as part of DataFrame equality comparison)
    @test DataFrame(Longwing.at_time(df, time_col, 30)) == DataFrame(A=3, B=13)

    @test DataFrame(Longwing.at_time(df, time_col, 0)) == DataFrame(A=[], B=[])

    @test DataFrame(Longwing.at_time(df, time_col, 1000)) == DataFrame(A=10, B=20)
end

# Test at_od
@testitem "at" begin
    println("at")
    using DataFrames
    # Sample data for at
    od_df = DataFrame(A=[0.1, 0.2, 0.3, 0.4, 0.5], B=[0.2, 0.3, 0.4, 0.5, 0.6])
    range_col = DataFrame(D=[10, 20, 30, 40, 50])

    @test Longwing.at(od_df, range_col, 30) == DataFrame(A=0.3, B=0.4)
    @test Longwing.at(od_df, range_col, 10) == DataFrame(A=0.1, B=0.2)
    @test isequal(Longwing.at(od_df, range_col, 5), DataFrame(A=missing, B=missing))


    od_df = DataFrame(A=[0.1, 0.2, 0.3, 0.4, 0.5], B=[0.2, 0.3, 0.4, 0.5, 0.6])
    range_col = DataFrame(A=[10, 20, 30, 40, 50], B=[30, 40, 50, 55, 35])

    @test Longwing.at(od_df, range_col, 30) == DataFrame(A=0.3, B=0.2)
    @test isequal(Longwing.at(od_df, range_col, 10), DataFrame(A=0.1, B=missing))
    @test Longwing.at(od_df, range_col, 37) == DataFrame(A=0.3, B=0.6)
    @test isequal(Longwing.at(od_df, range_col, 5), DataFrame(A=missing, B=missing))
    @test Longwing.at(od_df, range_col, 100) == DataFrame(A=0.5, B=0.6)
end

@testitem "expression" setup=[MockLongwing] begin
    println("expression")
    using DataFrames
    lw = read_longwing(MockLongwing.temp_file)
    lw.transformations["extra_transform"] = Dict{String,Any}("equation" => "sum([1,2,3,4])")
    trans_meta_map = Dict(Symbol(i) => Meta.parse(lw.transformations[i]["equation"])
                          for i in keys(lw.transformations))

    #Test numbers
    @test Longwing.run_transformation(lw, "5") == 5
    # Test strings
    @test Longwing.run_transformation(lw, "\"hello\"") == "hello"
    # Test functions
    @test eval(Longwing.run_transformation(lw, "sum([1, 2, 3])")) == 6
    # Test accessing transformations
    @test Longwing.run_transformation(lw, "extra_transform") == 10
    # Test accessing views
    @test Longwing.run_transformation(lw, "flow_cyt") == 1
    # Test accessing groups
    df = DataFrame(
        "FL1_A" => [54.0, 143.0, 25.0, 71.0, 0.0, 143.0, 0.0, 61.0],
        "SSC_H" => [0.11039991779173976, 0.18187190885323648,
            0.04740031742312117, 2.8133175148587766, 0.03522694651473101,
            0.272613196449465, 0.01778279410038923, 0.9955128609158501],
        "FSC_H" => [
            634.0, 965.0, 643.0, 1015.0,
            628.0, 1023.0, 373.0, 1023.0],
        "id" => collect(1:8),
        "longwing_well" => ["a1", "a1", "a1", "a1", "a2", "a2", "a2", "a2"],
        "FL1_A.max" => fill(1024.0, 8),
        "FL1_A.min" => fill(1.0, 8),
        "SSC_H.max" => fill(1.0, 8),
        "SSC_H.min" => fill(0.010045073642544625, 8),
        "FSC_H.max" => fill(1024.0, 8),
        "FSC_H.min" => fill(1.0, 8))
    @test Longwing.run_transformation(lw, "plate_01") == df[!, sort(names(df))]
    # Test other symbols - should just be returned
    @test Longwing.sexp_to_nested_list(:not_defined, lw, trans_meta_map) == :not_defined
    @test Longwing.sexp_to_nested_list(:(form_df(lw.samples)), lw, trans_meta_map) ==
        :(form_df(lw.samples))
    # Test samples
    df = DataFrame(
        "FL1_A" => [54.0, 143.0, 25.0, 71.0],
        "SSC_H" => [
            0.11039991779173976, 0.18187190885323648,
            0.04740031742312117, 2.8133175148587766],
        "FSC_H" => [634.0, 965.0, 643.0, 1015.0],
        "id" => [1, 2, 3, 4],
        "longwing_well" => ["a1", "a1", "a1", "a1"],
        "FL1_A.max" => fill(1024.0, 4),
        "FL1_A.min" => fill(1.0, 4),
        "SSC_H.max" => fill(1.0, 4),
        "SSC_H.min" => fill(0.010045073642544625, 4),
        "FSC_H.max" => fill(1024.0, 4),
        "FSC_H.min" => fill(1.0, 4))
    @test Longwing.run_transformation(lw, "plate_01_a1") ==
        df[!, sort(names(df))]
    # Test channels
    df = DataFrame(
        "FL1_A" => [54.0, 143.0, 25.0, 71.0],
        "id" => [1, 2, 3, 4],
        "longwing_well" => ["a1", "a1", "a1", "a1"],
        "FL1_A.max" => fill(1024.0, 4),
        "FL1_A.min" => fill(1.0, 4))
    @test Longwing.run_transformation(lw, "plate_01_a1.FL1_A") ==
        df[!, sort(names(df))]
    df = DataFrame(
        "SSC_H" => [
            0.11039991779173976, 0.18187190885323648,
            0.04740031742312117, 2.8133175148587766, 0.03522694651473101,
            0.272613196449465, 0.01778279410038923, 0.9955128609158501],
        "id" => [1, 2, 3, 4, 5, 6, 7, 8],
        "longwing_well" => ["a1", "a1", "a1", "a1", "a2", "a2", "a2", "a2"],
        "SSC_H.max" => fill(1.0, 8),
        "SSC_H.min" => fill(0.010045073642544625, 8))
    @test Longwing.run_transformation(lw, "plate_01.SSC_H") ==
        df[!, sort(names(df))]
    # Test groups
    df = DataFrame("FL1_A" => [54.0, 143.0, 25.0, 71.0, 0.0, 143.0, 0.0, 61.0],
        "id" => [1, 2, 3, 4, 5, 6, 7, 8], "longwing_well" => ["a1", "a1", "a1", "a1", "a2",
        "a2", "a2", "a2"], "FL1_A.max" => fill(1024.0, 8), "FL1_A.min" => fill(
        1.0, 8))
    @test Longwing.run_transformation(lw, "plate_01.FL1_A") ==
        df[!, sort(names(df))]
end

@testitem "blocked expressions" setup=[MockLongwing] begin
    using DataFrames
    lw = read_longwing(MockLongwing.temp_file)
    lw.transformations["extra_transform"] = Dict{String,Any}("equation" => "sum([1,2,3,4])")
    trans_meta_map = Dict(Symbol(i) => Meta.parse(lw.transformations[i]["equation"])
                          for i in keys(lw.transformations))

    @test_throws ErrorException "Blocked" Longwing.sexp_to_nested_list(:(rm(file)), lw, trans_meta_map)
    @test_throws ErrorException "Blocked" Longwing.sexp_to_nested_list(:(Base.Filesystem.unknown(file); force=true), lw, trans_meta_map)
    @test_throws ErrorException "Blocked" Longwing.sexp_to_nested_list(:(run("ls")), lw, trans_meta_map)
    @test_throws ErrorException "Blocked" Longwing.sexp_to_nested_list(:(@ccall 1), lw, trans_meta_map)
    @test_throws ErrorException "Blocked" Longwing.sexp_to_nested_list(:(@eval 1), lw, trans_meta_map)
end

@testitem "produce_views" setup=[environment_path] begin
    println("produce_views")
    lw = read_longwing("inputs/example.lw")
    trans_meta_map = Dict(Symbol(i) => Meta.parse(lw.transformations[i]["equation"])
                          for i in keys(lw.transformations))
    a = Longwing.produce_views(lw, trans_meta_map)
    # Test groups
    @test issetequal(
        keys(a), ["group1", "group2", "group3", "flowsub", "odsub", "sample", "mega"])
    @test issetequal(names(a["group1"]),
        ["plate_01_a5.OD", "plate_01_a5.flo", "plate_01_a1.OD",
            "plate_01_a1.flo", "plate_01_a9.OD", "plate_01_a9.flo"])
    @test issetequal(names(a["group2"]),
        ["plate_01_a8.OD", "plate_01_a8.flo", "plate_01_a3.OD",
            "plate_01_a3.flo", "plate_01_a7.OD", "plate_01_a7.flo"])
    @test issetequal(names(a["group3"]),
        ["plate_01_a2.OD", "plate_01_a2.flo", "plate_01_a1.OD",
            "plate_01_a1.flo", "plate_01_a3.OD", "plate_01_a3.flo"])
    @test a["group1"][1:3, "plate_01_a5.OD"] == Any[0.169, 0.173, 0.177]
    @test a["group2"][2:4, "plate_01_a8.OD"] == Any[0.152, 0.154, 0.157]
    @test a["group3"][(end-2):end, "plate_01_a3.flo"] == Any[211, 201, 209]
    # Test mega group
    @test issetequal(names(a["mega"]),
        ["plate_01_a5.OD", "plate_01_a5.flo", "plate_01_a1.OD",
            "plate_01_a1.flo", "plate_01_a9.OD", "plate_01_a9.flo",
            "plate_01_a8.OD", "plate_01_a8.flo", "plate_01_a3.OD", "plate_01_a3.flo",
            "plate_01_a7.OD", "plate_01_a7.flo"])
    @test a["mega"][1:3, "plate_01_a5.OD"] == Any[0.169, 0.173, 0.177]
    @test a["mega"][2:4, "plate_01_a8.OD"] == Any[0.152, 0.154, 0.157]
    @test a["mega"][(end-2):end, "plate_01_a3.flo"] == Any[211, 201, 209]
    # Test sample
    @test names(a["sample"]) == ["plate_01_time"]
    @test a["sample"][[1, 2, end - 1, end], "plate_01_time"] ==
        [544714, 1144314, 66544764, 67144719]
    # Test expressions
    @test issetequal(names(a["flowsub"]),
        ["plate_01_a5", "plate_01_a1", "plate_01_a9",
            "plate_01_a8", "plate_01_a3", "plate_01_a7"])
    @test issetequal(names(a["odsub"]),
        ["plate_01_a5", "plate_01_a1", "plate_01_a9",
            "plate_01_a8", "plate_01_a3", "plate_01_a7"])
    @test a["flowsub"][[1, 2, end - 1, end], "plate_01_a9"] ≈ [
        0.33333333333333215, -2.666666666666668, -160.66666666666669, -162.33333333333331]
    @test a["odsub"][[1, 2, end - 1, end], "plate_01_a3"] ≈
        [0.0026666666666666783, 0.0026666666666666783,
        -0.10200000000000009, -0.10133333333333328]

    # Test non-DataFrame handling
    # Numbers
    using DataFrames
    lw.views["number_view"] = Dict{String,Any}("data" => ["extra_transform"])
    lw.views["numbers_view2"] = Dict{String,Any}("data" => [
        "extra_transform", "extra_transform2"])
    lw.transformations["extra_transform"] = Dict{String,Any}("equation" => "42")
    lw.transformations["extra_transform2"] = Dict{String,Any}("equation" => "7")
    trans_meta_map = Dict(Symbol(i) => Meta.parse(lw.transformations[i]["equation"])
                          for i in keys(lw.transformations))
    out = Longwing.produce_views(lw, trans_meta_map; to_out=["number_view"])
    @test all(out["number_view"] .== Tables.table([42;;]))
    out = Longwing.produce_views(lw, trans_meta_map; to_out=["numbers_view2"])
    @test all(out["numbers_view2"] .== Tables.table([42 7]))
    # Matrices
    lw.views["matrix_view"] = Dict{String,Any}("data" => [
        "extra_transform3", "extra_transform4"])
    lw.transformations["extra_transform3"] = Dict{String,Any}("equation" => "[1 2 3; 4 5 6]")
    lw.transformations["extra_transform4"] = Dict{String,Any}("equation" => "[7 8; 10 11]")
    trans_meta_map = Dict(Symbol(i) => Meta.parse(lw.transformations[i]["equation"])
                          for i in keys(lw.transformations))
    out = Longwing.produce_views(lw, trans_meta_map; to_out=["matrix_view"])
    @test all(out["matrix_view"] .== Tables.table([1 2 3 7 8; 4 5 6 10 11]))
    # String
    lw.views["string_view"] = Dict{String,Any}("data" => ["string_transform"])
    lw.transformations["string_transform"] = Dict{String,Any}("equation" => "\"hello\"")
    trans_meta_map = Dict(Symbol(i) => Meta.parse(lw.transformations[i]["equation"])
                          for i in keys(lw.transformations))

    dir = mktempdir()
    using Logging
    io = IOBuffer()
    logger = SimpleLogger(io)
    with_logger(logger) do
        Longwing.view_to_csv(lw, trans_meta_map; outdir=dir, to_out=["string_view"])
    end
    str = String(take!(io))

    comparison = "string_view = hello"
    @test contains(str, comparison)
    @test isfile(joinpath(dir, "string_view.txt"))
    @test readlines(joinpath(dir, "string_view.txt")) == ["string_view = hello"]

    # Test errors
    lw.views["bad_view"] = Dict{String,Any}("data" => ["nonexistent_group"])
    msg = "UndefVarError: `nonexistent_group` not defined in `Longwing`"
    @test_throws msg Longwing.produce_views(lw, trans_meta_map; to_out=["bad_view"])

    # More complex views
    dir = mktempdir()
    x = read_data("inputs/views.xlsx")
    write_longwing(x, joinpath(dir, "views.lw"))
    lw = read_longwing(joinpath(dir, "views.lw"))
    trans_meta_map = Dict(Symbol(i) => Meta.parse(lw.transformations[i]["equation"])
                          for i in keys(lw.transformations))
    out = Longwing.produce_views(lw, trans_meta_map)

    @test issetequal(names(out["v1"]), ["plate_01_a1.700", "plate_01_a1.od"])
    @test issetequal(names(out["v2"]), ["plate_01_a1"])
    @test issetequal(names(out["v3"]), Longwing.expand_groups("plate_01_[a,b][1:4].[700,od]"))
    @test issetequal(names(out["v4"]), Longwing.expand_groups("plate_01_[a,b][1:4].[700,od]"))
    @test issetequal(names(out["v5"]), Longwing.expand_groups("plate_01_[a,b][1:4].[700,od], plate_01_e[5:7].[700,od]"))
    @test issetequal(names(out["v6"]), Longwing.expand_groups("plate_01_[a,b][1:4].[od,700,od_1,700_1], plate_01_e[5:7].[od,700,od_1,700_1],plate_01_time,plate_01_a1.[od_2,700_2],plate_01_[a,b][1:4],plate_01_a6.[od,700],plate_01_a7"))
end

@testitem "kw name collision" setup=[environment_path] begin
    println("kw name collision")
    dir = mktempdir()
    cp("inputs/kw_name_collision.xlsx", joinpath(dir, "kw_name_collision.xlsx"))
    lw = read_data(joinpath(dir, "kw_name_collision.xlsx"))
    write_longwing(lw, joinpath(dir, "kw_name_collision.lw"))
    lw = read_longwing(joinpath(dir, "kw_name_collision.lw"))
    trans_meta_map = Dict(Symbol(i) => Meta.parse(lw.transformations[i]["equation"])
                          for i in keys(lw.transformations))
    out = Longwing.produce_views(lw, trans_meta_map)
    @test !isempty(out)
end

@testitem "non-table views" setup=[environment_path] begin
    println("non-table views")
    dir = mktempdir()
    cp("inputs/non_table_views.xlsx", joinpath(dir, "non_table_views.xlsx"))
    lw = read_data(joinpath(dir, "non_table_views.xlsx"))
    write_longwing(lw, joinpath(dir, "non_table_views.lw"))
    lw = read_longwing(joinpath(dir, "non_table_views.lw"))
    trans_meta_map = Dict(Symbol(i) => Meta.parse(lw.transformations[i]["equation"])
                          for i in keys(lw.transformations))

    using Logging
    io = IOBuffer()
    logger = SimpleLogger(io)

    with_logger(logger) do
        Longwing.view_to_csv(lw, trans_meta_map)
    end
    str = String(take!(io))
    @test contains(str, "Info: method = Longwing.Endpoints(10.0, 20.0)") ||
        contains(str, "Info: method = Endpoints(10.0, 20.0)")
end

@testitem "to_rfi" begin
    println("to_rfi")
    lw = read_longwing("inputs/example.lw")
    out = Longwing.to_rfi(lw, "plate_02_a1")
    # Linear test with no gain
    @test out[!, "FSC_H"] == [628.0, 1023.0, 373.0, 1023.0]
    @test out[!, "FSC_H.max"] == fill(1024.0, 4)
    @test out[!, "FSC_H.min"] == fill(1.0, 4)
    # Scaling factor gain test
    @test out[!, "FL1_H"] ≈ [2.26449442, 134.40293884, 1.53816354, 64.86381531]
    # Log scaling test
    @test out[!, "SSC_H"] ≈ [0.03522695, 0.2726132, 0.01778279, 0.99551286]
end

@testitem "raw metadata" begin
    println("raw metadata")
    lw = read_longwing("inputs/example.lw")
    metadata = lw.samples.metadata[lw.samples.name .== "plate_02_a1.FL1_A"][1]
    @test haskey(metadata, "raw_metadata")
    @test metadata["raw_metadata"]["creator"] == "CELLQuest<aa> 3.3"
    @test metadata["raw_metadata"]["fcsversion"] == "3"
end

@testitem "summary" begin
    println("summary")
    summary("inputs/summarise.lw", LongwingData(); plot=true)
    @test isfile("inputs/summarise.lw.pdf")
    rm("inputs/summarise.lw.pdf")
    summary("inputs/small.fcs", FlowCytometryData(); plot=true, csv=true)
    @test isfile("inputs/small.fcs.pdf")
    @test isfile("inputs/small.fcs.csv")
    rm("inputs/small.fcs.pdf")
    rm("inputs/small.fcs.csv")
    summary("inputs/spectramax-summarise.txt", SpectraMax(); plot=true, csv=true)
    @test isfile("inputs/spectramax-summarise.txt.pdf")
    @test isfile("inputs/spectramax-summarise.txt_600.csv")
    @test isfile("inputs/spectramax-summarise.txt_700.csv")
    @test isfile("inputs/spectramax-summarise.txt_535_485.csv")
    rm.(["inputs/spectramax-summarise.txt.pdf",
        "inputs/spectramax-summarise.txt_600.csv",
        "inputs/spectramax-summarise.txt_700.csv",
        "inputs/spectramax-summarise.txt_535_485.csv"])
    summary("inputs/biotek-summarise.csv", BioTek(); plot=true, csv=true)
    @test isfile("inputs/biotek-summarise.csv.pdf")
    @test isfile("inputs/biotek-summarise.csv_OD_700.csv")
    @test isfile("inputs/biotek-summarise.csv_OD_600.csv")
    @test isfile("inputs/biotek-summarise.csv_GFP_485_530.csv")
    rm.(["inputs/biotek-summarise.csv.pdf",
        "inputs/biotek-summarise.csv_OD_700.csv",
        "inputs/biotek-summarise.csv_OD_600.csv",
        "inputs/biotek-summarise.csv_GFP_485_530.csv"])
    summary("inputs/tecan-summarise.xlsx", Tecan(); plot=true, csv=true)
    @test isfile("inputs/tecan-summarise.xlsx.pdf")
    @test isfile("inputs/tecan-summarise.xlsx_OD_600.csv")
    @test isfile("inputs/tecan-summarise.xlsx_OD_700.csv")
    @test isfile("inputs/tecan-summarise.xlsx_GFP.csv")
    rm.(["inputs/tecan-summarise.xlsx.pdf",
        "inputs/tecan-summarise.xlsx_OD_600.csv",
        "inputs/tecan-summarise.xlsx_OD_700.csv",
        "inputs/tecan-summarise.xlsx_GFP.csv"])
    summary("inputs/bmg-summarise.csv", BMG(); plot=true, csv=true)
    @test isfile("inputs/bmg-summarise.csv.pdf")
    @test isfile("inputs/bmg-summarise.csv_ABS_600_0_nm.csv")
    @test isfile("inputs/bmg-summarise.csv_ABS_700_0_nm.csv")
    @test isfile("inputs/bmg-summarise.csv_FI_YFP_pAN1717.csv")
    rm.(["inputs/bmg-summarise.csv.pdf",
        "inputs/bmg-summarise.csv_ABS_600_0_nm.csv",
        "inputs/bmg-summarise.csv_ABS_700_0_nm.csv",
        "inputs/bmg-summarise.csv_FI_YFP_pAN1717.csv"])
    summary("inputs/pr_folder", GenericTabular(); plot=true, csv=true)
    @test isfile("inputs/pr_folder.pdf")
    @test isfile("inputs/pr_folder_OD.csv")
    @test isfile("inputs/pr_folder_flo.csv")
    rm.(["inputs/pr_folder.pdf", "inputs/pr_folder_OD.csv", "inputs/pr_folder_flo.csv"])

    # Error checking
    @test_throws "File type" summarise("biotek-summarise.csv")
    @test_throws "Unsupported" summarise("inputs/unknown.txt"; type="unknown")
end

@testitem "issue 34" setup=[environment_path] begin
    # Importing from excel with single channel reads a Int, not a String
    # which can then fail at regex
    read_data("inputs/issue34.xlsx")
end

@testitem "empty template rows" setup=[environment_path] begin
    # Test the empty rows in the template don't stop data being imported
    lw = read_data("inputs/blank_rows.xlsx")
    @test "plate_01_time" in keys(lw["samples"])
    @test "plate_02_time" in keys(lw["samples"])
    @test "g1" in keys(lw["groups"])
    @test "g2" in keys(lw["groups"])
    @test "t1" in keys(lw["transformations"])
    @test "t2" in keys(lw["transformations"])
    @test "v1" in keys(lw["views"])
    @test "v2" in keys(lw["views"])
end

@testitem "invalid channel map" setup=[environment_path] begin
    # Test that invalid channel map entries are handled gracefully
    @test_throws "Some channels in the channel map are not in a valid format" read_data("inputs/invalid_channel_map.xlsx")
end

@testitem "requested missing channel" setup=[environment_path] begin
    # Test that requesting a channel that isn't in the data throws an error
    @test_throws "Requested channel missing_channel_i_want not found in file" read_data("inputs/requested_but_missing_channel.xlsx")
end

@testitem "no specified channels" setup = [environment_path] begin
    # Test that if no channels are specified, all channels are read in
    lw = read_data("inputs/no-specified-channels.xlsx")
    @test "abs600" in keys(lw["samples"]["plate_01_a1"]["values"])
    @test "abs700" in keys(lw["samples"]["plate_01_a1"]["values"])
    @test "535_485" in keys(lw["samples"]["plate_01_a1"]["values"])
    @test "FL1_A" in keys(lw["samples"]["plate_02_a1"]["values"])
end

@testitem "group metadata" setup=[environment_path] begin
    # Test that group metadata is read in correctly
    lw = read_data("inputs/extra-metadata.xlsx")
    @test lw["groups"]["plate1"]["metadata"] == Dict("autodefined" => "false", "Plate reader" => true)
    @test lw["groups"]["otherdata"]["metadata"] == Dict("autodefined" => "false", "Plate reader" => false)
end
