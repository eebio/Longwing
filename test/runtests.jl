using TestItemRunner
using Longwing

# Remove any existing coverage files
for f in readdir(pwd(), join=true)
    if endswith(f, ".cov")
        rm(f)
    end
end

for f in readdir(joinpath(pwd(), "..", "src"), join=true)
    if endswith(f, ".cov")
        rm(f)
    end
end

for f in readdir(joinpath(pwd(), "..", "src", "flow"), join=true)
    if endswith(f, ".cov")
        rm(f)
    end
end

for f in readdir(joinpath(pwd(), "..", "src", "interactive"), join=true)
    if endswith(f, ".cov")
        rm(f)
    end
end

@testsnippet environment_path begin
    println("environment path")
    if "GITHUB_WORKSPACE" ∉ keys(ENV)
        ENV["GITHUB_WORKSPACE"] = joinpath(pwd(), "..")
    end
end

@testitem "update example.lw and summarise.lw" setup=[environment_path] begin
    println("update example.lw and summarise.lw")
    data = read_data("inputs/example.xlsx")
    data["metadata"]["date_created"] = ""
    data["metadata"]["date_modified"] = ""
    data["metadata"]["versioninfo"] = ""
    data["metadata"]["Manifest.toml"] = ""
    data["metadata"]["Project.toml"] = ""
    write_longwing(data, "inputs/example.lw")

    data = read_data("inputs/summarise.xlsx")
    data["metadata"]["date_created"] = ""
    data["metadata"]["date_modified"] = ""
    data["metadata"]["versioninfo"] = ""
    data["metadata"]["Manifest.toml"] = ""
    data["metadata"]["Project.toml"] = ""
    write_longwing(data, "inputs/summarise.lw")
end

@run_package_tests
