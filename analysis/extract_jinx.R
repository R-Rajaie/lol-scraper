# pulls one row per jinx game out of the raw riot match json files and saves
# it as analysis/output/jinx_gold_damage.csv, which the project report reads
#
# usage: Rscript analysis/extract_jinx.R
# (works from anywhere inside the repo)

# install jsonlite if it's missing, then load it
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  install.packages("jsonlite", repos = "https://cloud.r-project.org")
}
library(jsonlite)

# which champ to pull. change this to redo the whole thing for someone else
CHAMPION <- "Jinx"

# --- find the project root ---------------------------------------------------
# walk up folders from wherever we are until we hit one with .git or
# requirements.txt in it, so the paths below work no matter where you run this
find_project_root <- function(start = getwd(), markers = c(".git", "requirements.txt")) {
  dir <- normalizePath(start, mustWork = FALSE)
  repeat {
    if (any(file.exists(file.path(dir, markers)))) return(dir)
    parent <- dirname(dir)
    if (parent == dir) return(NULL)  # hit the top of the drive, give up
    dir <- parent
  }
}

project_root <- find_project_root()
if (is.null(project_root)) stop("Could not locate the lol-scraper project root.")

# where stuff lives
matches_dir <- file.path(project_root, "data/raw/matches")
buckets_path <- file.path(project_root, "data/raw/rank_meta/puuid_buckets.json")
out_dir <- file.path(project_root, "analysis/output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# every downloaded match file
match_files <- list.files(matches_dir, pattern = "\\.json$", full.names = TRUE)
cat(sprintf("Found %d match files\n", length(match_files)))

# lookup table: player id -> rank group (low/mid/high/elite) for every player
# the scraper sampled. a match gets the rank group of the sampled player it
# came from, since ranked matchmaking puts similar ranks together
puuid_bucket <- unlist(fromJSON(buckets_path, simplifyVector = TRUE))

# --- extraction --------------------------------------------------------------
# most files don't have jinx in them, so do a cheap text search first and only
# fully parse the json when she's actually there. way faster
champ_pattern <- sprintf('"championName":\\s*"%s"', CHAMPION)

# riot sometimes leaves fields out, so turn missing (NULL) values into NA
get_num <- function(x) if (is.null(x)) NA_real_ else as.numeric(x)
get_chr <- function(x) if (is.null(x)) NA_character_ else as.character(x)

# reads one match file and returns the jinx row(s), or NULL if there's no jinx
extract_champion <- function(path) {
  # read the whole file as text and skip it early if jinx isn't in it
  txt <- readChar(path, file.size(path), useBytes = TRUE)
  if (!grepl(champ_pattern, txt, perl = TRUE)) return(NULL)

  # parse the json. simplifyVector = FALSE keeps nested stuff as plain lists,
  # which stops weird optional fields from breaking the parse
  match <- tryCatch(fromJSON(txt, simplifyVector = FALSE), error = function(e) NULL)
  info <- match$info
  if (is.null(info) || is.null(info$participants)) return(NULL)  # broken file

  # figure out the match's rank group from whichever sampled players are in it.
  # if more than one is in there, take the most common group and note if they
  # disagreed
  puuids <- vapply(info$participants, function(p) get_chr(p$puuid), character(1))
  seeded <- puuid_bucket[puuids[puuids %in% names(puuid_bucket)]]
  bucket <- if (length(seeded) > 0) names(which.max(table(seeded))) else NA_character_
  bucket_conflict <- length(unique(seeded)) > 1

  # go through all 10 players and keep only the jinx player's stats
  rows <- lapply(info$participants, function(p) {
    if (!identical(p$championName, CHAMPION)) return(NULL)
    data.frame(
      matchId = get_chr(match$metadata$matchId),
      puuid = get_chr(p$puuid),                  # swapped for an anonymous id later
      platformId = get_chr(info$platformId),     # region, e.g. NA1 / EUW1 / KR
      queueId = get_num(info$queueId),           # 420 = ranked solo/duo
      gameVersion = get_chr(info$gameVersion),   # patch number
      gameCreation = get_num(info$gameCreation), # when the game was played
      gameDuration = get_num(info$gameDuration), # game length in seconds
      rankBucket = bucket,
      bucketConflict = bucket_conflict,
      teamPosition = get_chr(p$teamPosition),    # lane, BOTTOM for normal jinx
      win = isTRUE(p$win),
      earlySurrender = isTRUE(p$gameEndedInEarlySurrender),  # remake flag
      goldEarned = get_num(p$goldEarned),
      totalDamageDealtToChampions = get_num(p$totalDamageDealtToChampions)
    )
  })
  do.call(rbind, rows)  # glue the (usually one) row together
}

# run it on every file, printing progress every 2000 files
n <- length(match_files)
all_rows <- vector("list", n)
for (i in seq_len(n)) {
  all_rows[[i]] <- extract_champion(match_files[i])
  if (i %% 2000 == 0) cat(sprintf("  processed %d / %d files\n", i, n))
}
df <- do.call(rbind, all_rows)  # stack everything into one data frame
cat(sprintf("Extracted %d %s rows\n", nrow(df), CHAMPION))

# the real cleaning happens in the project report so every dropped row gets reported
# there. this just removes exact duplicates in case a match got downloaded twice
df <- df[!duplicated(df), ]

# swap riot account ids for plain numbers (1, 2, 3, ...) so we can still tell
# when the same player shows up twice without publishing their account ids
df$playerId <- as.integer(factor(df$puuid))
df$puuid <- NULL

# save it
out_path <- file.path(out_dir, sprintf("%s_gold_damage.csv", tolower(CHAMPION)))
write.csv(df, out_path, row.names = FALSE)
cat(sprintf("Saved %s\n", out_path))
