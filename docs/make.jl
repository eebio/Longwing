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
        "plate_readers/quantification.md",
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

deploydocs(
    repo="github.com/eebio/Longwing",
    devbranch="dev"
)
