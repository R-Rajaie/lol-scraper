# Extract one row per Jinx player-game from the raw Match-V5 JSON files.
# Writes analysis/output/jinx_gold_damage.csv, which the report reads.
#
# Usage: Rscript analysis/extract_jinx.R
# (run from anywhere inside the repo)

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  install.packages("jsonlite", repos = "https://cloud.r-project.org")
}
library(jsonlite)

CHAMPION <- "Jinx"

# --- Locate project root -----------------------------------------------------
find_project_root <- function(start = getwd(), markers = c(".git", "requirements.txt")) {
  dir <- normalizePath(start, mustWork = FALSE)
  repeat {
    if (any(file.exists(file.path(dir, markers)))) return(dir)
    parent <- dirname(dir)
    if (parent == dir) return(NULL)
    dir <- parent
  }
}

project_root <- find_project_root()
if (is.null(project_root)) stop("Could not locate the lol-scraper project root.")

matches_dir <- file.path(project_root, "data/raw/matches")
buckets_path <- file.path(project_root, "data/raw/rank_meta/puuid_buckets.json")
out_dir <- file.path(project_root, "analysis/output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

match_files <- list.files(matches_dir, pattern = "\\.json$", full.names = TRUE)
cat(sprintf("Found %d match files\n", length(match_files)))

# Rank bucket (low/mid/high/elite) of each seeded player. A match inherits
# the bucket of the seeded player(s) it was downloaded for, since ranked
# matchmaking pairs players of similar rank.
puuid_bucket <- unlist(fromJSON(buckets_path, simplifyVector = TRUE))

# --- Extraction --------------------------------------------------------------
# Most files contain no Jinx, so check the raw text before paying for a full
# JSON parse. simplifyVector = FALSE keeps irregular nested fields from
# breaking jsonlite's data.frame simplification.
champ_pattern <- sprintf('"championName":\\s*"%s"', CHAMPION)

get_num <- function(x) if (is.null(x)) NA_real_ else as.numeric(x)
get_chr <- function(x) if (is.null(x)) NA_character_ else as.character(x)

extract_champion <- function(path) {
  txt <- readChar(path, file.size(path), useBytes = TRUE)
  if (!grepl(champ_pattern, txt, perl = TRUE)) return(NULL)

  match <- tryCatch(fromJSON(txt, simplifyVector = FALSE), error = function(e) NULL)
  info <- match$info
  if (is.null(info) || is.null(info$participants)) return(NULL)

  # If several seeded players share the match, use their most common bucket
  # and record whether they disagreed.
  puuids <- vapply(info$participants, function(p) get_chr(p$puuid), character(1))
  seeded <- puuid_bucket[puuids[puuids %in% names(puuid_bucket)]]
  bucket <- if (length(seeded) > 0) names(which.max(table(seeded))) else NA_character_
  bucket_conflict <- length(unique(seeded)) > 1

  rows <- lapply(info$participants, function(p) {
    if (!identical(p$championName, CHAMPION)) return(NULL)
    data.frame(
      matchId = get_chr(match$metadata$matchId),
      puuid = get_chr(p$puuid),
      platformId = get_chr(info$platformId),
      queueId = get_num(info$queueId),
      gameVersion = get_chr(info$gameVersion),
      gameCreation = get_num(info$gameCreation),
      gameDuration = get_num(info$gameDuration),
      rankBucket = bucket,
      bucketConflict = bucket_conflict,
      teamPosition = get_chr(p$teamPosition),
      win = isTRUE(p$win),
      earlySurrender = isTRUE(p$gameEndedInEarlySurrender),
      goldEarned = get_num(p$goldEarned),
      totalDamageDealtToChampions = get_num(p$totalDamageDealtToChampions)
    )
  })
  do.call(rbind, rows)
}

n <- length(match_files)
all_rows <- vector("list", n)
for (i in seq_len(n)) {
  all_rows[[i]] <- extract_champion(match_files[i])
  if (i %% 2000 == 0) cat(sprintf("  processed %d / %d files\n", i, n))
}
df <- do.call(rbind, all_rows)
cat(sprintf("Extracted %d %s rows\n", nrow(df), CHAMPION))

# Cleaning is done in the report so every exclusion is documented there;
# this file only drops exact duplicates from double-ingested matches.
df <- df[!duplicated(df), ]

# Replace account IDs with an anonymous integer so repeat players can be
# counted without publishing Riot account identifiers.
df$playerId <- as.integer(factor(df$puuid))
df$puuid <- NULL

out_path <- file.path(out_dir, sprintf("%s_gold_damage.csv", tolower(CHAMPION)))
write.csv(df, out_path, row.names = FALSE)
cat(sprintf("Saved %s\n", out_path))
