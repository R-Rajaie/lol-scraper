# MATH 261A Project 1 — Version 1

**Author:** Xinyi Xu
**Submission date:** September 25, 2026

## Project description

This project uses simple linear regression to study the association between annual mean PM2.5 concentration and age-adjusted asthma emergency department visit rates across California census tracts using CalEnviroScreen 5.0.

## Repository structure

- `project1_version1.qmd` — Quarto source for the paper.
- `references.bib` — BibTeX references used by the paper.
- `README.md` — project description and reproducibility notes.
- `data/` — optional local copy of the raw CalEnviroScreen CSV. This directory is ignored by Git and should not be committed.

## Data source

The data are from **CalEnviroScreen 5.0**, published by the California Office of Environmental Health Hazard Assessment (OEHHA) and distributed through the California Open Data Portal.

Data page: <https://lab.data.ca.gov/dataset/calenviroscreen-5-0>

The metadata supplied with the dataset lists the public access level as public, states that there are no restrictions on public use, and lists the license field as not specified. The raw data are not included in this repository. The Quarto file first looks for a local copy and otherwise attempts to read the official download URL.

## Software

The analysis is written in R and uses `tidyverse`, `ggpubr`, `patchwork`, and `knitr`. The report is rendered with Quarto.

## External resources and LLM use

External resources were used to help prepare this project. ChatGPT was used to assist with organizing the Quarto document, checking R code structure, and editing prose. Statistical results and interpretations should be reviewed by the author before submission. OEHHA documentation and the cited scholarly literature were used for background, variable definitions, and methodological context.
