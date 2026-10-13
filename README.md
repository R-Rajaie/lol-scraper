# Turning Gold into Damage: Jinx in Ranked League of Legends

**Author:** Ryan Rajaie
**Date of submission:** October 12, 2026
**Course:** MATH 261A (Regression Theory and Methods), Project 1

This project fits a simple linear regression of damage dealt to champions per
minute on gold earned per minute for the champion Jinx, using 2,795 ranked
solo/duo games collected from the Riot Games API. The project report source is
`analysis/report/jinx_gold_damage.qmd` and the rendered report is
`analysis/report/jinx_gold_damage.pdf`.

## Project structure

```
lol-scraper/
├── lol-scraper.Rproj          R project file
├── README.md
├── requirements.txt           Python dependencies for the data collection scripts
├── lolobj/                    Python package that downloads match data
│   ├── config.py              API key loading and data paths
│   ├── riot_client.py         Rate-limited client for the Riot API
│   └── ingest/
│       ├── seed_matches.py    Samples players by rank and region, downloads their matches
│       ├── download_matches.py
│       └── storage.py
├── data/                      Raw match JSON (not in the repository; see below)
├── materials/                 Lecture slides and rubric (local only, not in the repository)
└── analysis/
    ├── extract_jinx.R         Reads the raw match files and writes one row per Jinx game
    ├── output/
    │   └── jinx_gold_damage.csv   Extracted Jinx games used by the project report
    └── report/
        ├── jinx_gold_damage.qmd   The project report (Quarto source)
        ├── jinx_gold_damage.pdf   The rendered project report
        └── references.bib         Bibliography (BibTeX)
```

## Reproducing the analysis

The project report only needs `analysis/output/jinx_gold_damage.csv`, which is included.
To render it:

1. Install the R packages `tidyverse` and `knitr`, and a TeX distribution for
   the PDF (for example, run `tinytex::install_tinytex()` in R).
2. Open `lol-scraper.Rproj` in RStudio, then open
   `analysis/report/jinx_gold_damage.qmd`.
3. Click Render. Use the editor's Source mode rather than Visual mode, which
   can rewrite the inline R code when it saves the file.

To rebuild the dataset from scratch:

1. Get a Riot API key from <https://developer.riotgames.com> and put it in a
   `.env` file at the project root as `RIOT_API_KEY=RGAPI-...`.
2. Install the Python dependencies (`pip install -r requirements.txt`) and run
   `python -m lolobj.ingest.seed_matches` to download matches into
   `data/raw/`. The defaults sample 30 players per rank group in each of NA,
   EUW and KR and download each player's 20 most recent ranked solo/duo
   matches. Match histories change over time, so a new download will not
   reproduce the exact same games.
3. Run `Rscript analysis/extract_jinx.R` to rebuild the CSV.

## Data license

The data comes from the Riot Games API and are subject to the
[Riot Developer Portal policies](https://developer.riotgames.com/policies/general)
and API terms of use. Raw match files are not redistributed in this
repository. The included CSV contains only per-game statistics for Jinx
players, with Riot account identifiers replaced by anonymous integers.

This project isn't endorsed by Riot Games and doesn't reflect the views or
opinions of Riot Games or anyone officially involved in producing or managing
Riot Games properties. Riot Games, and all associated properties are
trademarks or registered trademarks of Riot Games, Inc.

## Use of external resources

Anthropic's Claude Opus 5.5 (both in-browser and through Claude Code) was used in aid of writing code, formatting and correcting report syntax, and verifying math.