using Documenter, Longwing
using DocumenterInterLinks

links = InterLinks(
    "DataInterpolations" => "https://docs.sciml.ai/DataInterpolations/stable/objects.inv",
)

PAGES = [
    "Introduction" => "index.md",
    "Getting Started with Longwing" => "tutorial.md",
    "Plate Readers" => [
        "plate_readers/index.md",
        "plate_readers/calibration.md",
        "plate_readers/growth_rate.md",
        "plate_readers/fluorescence.md",
        "plate_readers/smoothing.md",
        "plate_readers/compatibility.md",
        "plate_readers/other_functions.md",
    ],
    "Flow Cytometry" => [
        "flow_cytometers/index.md",
        "flow_cytometers/flow_tutorial.md",
        "flow_cytometers/auto_gating.md",
        "flow_cytometers/manual_gating.md",
        "flow_cytometers/mef_calibration.md",
        "flow_cytometers/transforms.md",
    ],
    "Data Format" => "data_format.md",
    "Command Line Interface" => "cli.md",
    "Excel Interface" => "excel.md",
    "API" => "api.md"
]

modules = [Longwing
]

makedocs(sitename="Longwing Data Standard",
    repo=Remotes.GitHub("eebio", "Longwing"), modules=modules, checkdocs=:exports,
    pages=PAGES, plugins=[links],
    format = Documenter.HTML(assets = [RawHTMLHeadContent("""<meta name="google-site-verification" content="JfyX6r31rrWQUAIZV5kiaTJfmdXj0MP3XkwLIsah1_A" />""")]))

# --- AUTOMATED SITEMAP GENERATION ---
@info "Generating sitemap.xml..."
build_dir = joinpath(@__DIR__, "build")
sitemap_path = joinpath(build_dir, "sitemap.xml")

# Collect all generated HTML files in the build folder
html_files = String[]
for (root, dirs, files) in walkdir(build_dir)
    for file in files
        if endswith(file, ".html")
            # Calculate the relative path from the build root
            rel_path = relpath(joinpath(root, file), build_dir)

            # Convert standard 'index.html' references into clean directory paths
            if rel_path == "index.html"
                push!(html_files, "")
            elseif endswith(rel_path, "index.html")
                push!(html_files, replace(rel_path, "index.html" => ""))
            else
                push!(html_files, rel_path)
            end
        end
    end
end

# Write out the structured sitemap layout
open(sitemap_path, "w") do io
    write(io, """<?xml version="1.0" encoding="UTF-8"?>\n""")
    write(io, """<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n""")
    for file_path in unique(html_files)
        # Construct the clean absolute URL for Googlebot
        url = "https://eebio.github.io/Longwing/stable/" * file_path
        write(io, """  <url>\n""")
        write(io, """    <loc>$(url)</loc>\n""")
        if file_path == ""
            write(io, """    <priority>1.0</priority>\n""")
        elseif contains(file_path, "tutorial")
            write(io, """    <priority>0.8</priority>\n""")
        else
            write(io, """    <priority>0.5</priority>\n""")
        end
        write(io, """  </url>\n""")
    end
    write(io, """</urlset>\n""")
end
@info "sitemap.xml successfully written to $(sitemap_path)"

deploydocs(
    repo="github.com/eebio/Longwing",
    devbranch="dev"
)
