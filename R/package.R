is_tarball <- function(package_input) {
  is_tarball <- grepl("[.]tar[.]gz$", package_input)

  is_tarball
}

is_git_repo_url <- function(package_input) {
  provider <- tryCatch({
    get_provider(package_input)
  }, error = function(e) {
    FALSE
  })

  if (is.character(provider)) {
    provider_regex <- AVAILABLE_PROVIDERS[[provider]]
    grepl(paste0(provider_regex, "/[^/]+/.+"), package_input)
  } else {
    FALSE
  }
}

is_package <- function(path) {
  tryCatch({
    devtools::is.package(devtools::as.package(path))
  }, error = function(e) {
    FALSE
  })
}

tarball_to_package_dir <- function(location) {
  if (!file.exists(location)) {
    tarball_location <- tempfile()

    utils::download.file(location, tarball_location, quiet = TRUE)
  } else {
    tarball_location <- location
  }

  package_dir <- file.path(normalized_tempdir(), digest::digest(Sys.time()))

  dir.create(package_dir)

  tryCatch({
    utils::untar(tarball_location, exdir = package_dir)
  }, warning = function(w) {
    stop("Error untaring downloaded R package: ", w)
  })

  # Untarring an R package tar.gz will result in a subdirectory of the package
  # name. The package_dir will only have that in it, so this should always
  # end up with the right package_dir for downstream.
  if (!is_package(package_dir) &&
      is_package(dir(package_dir, full.names = TRUE)[1]))
    package_dir <- dir(package_dir, full.names = TRUE)[1]

  if (!is_package(package_dir))
    stop("Problem downloading package from ", url,
         "\nUnable to find package root after untarring")

  package_dir
}

git_repo_url_to_package_dir <- function(url) {
  if (grepl("/.+@.+$", url)) {
    branch <- gsub(".+/.+@(.+)", "\\1", url)
    url <- gsub("(.+/.+)@(.+)", "\\1", url)
  } else {
    branch <- NULL
  }

  url <- make_https_remote(url)

  token <- get_token(url)

  package_dir <- file.path(normalized_tempdir(),
                           digest::digest(repo_stub(url)))

  unlink(package_dir, recursive = TRUE)

  git2r::clone(url = url, local_path = package_dir,
               credentials = git2r::cred_token(token), branch = branch,
               progress = FALSE)

  package_dir
}

get_gitCRAN_tempdir <- function() {
  gitCRAN_tempdir <- file.path(normalized_tempdir(), "gitCRAN")

  if (!dir.exists(gitCRAN_tempdir))
    dir.create(gitCRAN_tempdir, showWarnings = FALSE, recursive = TRUE)

  gitCRAN_tempdir
}

get_package_build_dir <- function() {
  build_dir <- file.path(get_gitCRAN_tempdir(), "packages")

  if (!dir.exists(build_dir))
    dir.create(build_dir, showWarnings = FALSE, recursive = TRUE)

  build_dir
}

normalize_package <- function(package, packages_tempdir,
                              available_packages = available.packages()) {
  if (is_tarball(package)) {
    package_dir <- tarball_to_package_dir(package)
  } else if (is_git_repo_url(package)) {
    package_dir <- git_repo_url_to_package_dir(package)
  } else if (dir.exists(package)) {
    package_dir <- normalizePath(package)
  } else if (package %in% rownames(available_packages)) {
    package_tarball <- download.packages(
      package,
      normalized_tempdir(),
      available = available_packages
    )[, 2]
    package_dir <- tarball_to_package_dir(package_tarball)
  } else {
    stop("Not able to identify source type of ", package)
  }

  if (normalizePath(dirname(package_dir)) != normalizePath(packages_tempdir))
    file.copy(package_dir, packages_tempdir, recursive = TRUE)

  normalizePath(file.path(packages_tempdir, basename(package_dir)))
}

normalize_packages <- function(packages, packages_tempdir,
                               available_packages = available.packages()) {
  vapply(
    packages,
    function(package) {
      normalize_package(package, packages_tempdir, available_packages)
    },
    character(1)
  )
}

get_package_name <- function(package_dir) {
  read.dcf(file.path(package_dir, "DESCRIPTION"), "Package")[[1]]
}

get_package_version <- function(package_dir) {
  read.dcf(file.path(package_dir, "DESCRIPTION"), fields = "Version")[[1]]
}

get_package_deps <- function(package,
                             available_packages = available.packages()) {
  if (dir.exists(package)) {
    imports <- read.dcf(file.path(package, "DESCRIPTION"), fields = "Imports")

    if (is.na(imports)) {
      deps <- c()
    } else {
      deps <- devtools::parse_deps(imports)$name
    }
  } else if (package %in% available_packages[, "Package"]) {
    deps <- tools::package_dependencies(
      package,
      db = available_packages,
      which = "Imports",
      recursive = TRUE
    )[[package]]
  } else {
    stop("Unable to find the package ", package)
  }

  recursive_deps <- Reduce(
    c,
    lapply(deps, function(dep) {
      tools::package_dependencies(
        dep,
        db = available_packages,
        which = "Imports",
        recursive = TRUE
      )[[dep]]
    })
  )

  deps <- unique(c(deps, recursive_deps))

  filter_base_dependencies(deps)
}

get_packages_deps <- function(packages, available_packages) {
  unique(Reduce(c, lapply(packages, get_package_deps, available_packages)))
}

filter_base_dependencies <- function(dependencies) {
  installed_packages <- installed.packages()
  installed_packages <- installed_packages[
    !is.na(installed_packages[, "Priority"]),
  ]
  base_packages <- installed_packages[
    installed_packages[, "Priority"] == "base", "Package"
  ]

  setdiff(dependencies, base_packages)
}

prepare_package <- function(package, subrepo_dir, type, build,
                            available_packages, container = NULL,
                            build_deps = TRUE) {
  package <- normalize_package(package, get_package_build_dir(),
                               available_packages)

  package_dir <- file.path(subrepo_dir, "src", "contrib")

  deps <- filter_installed(
    get_package_deps(package, available_packages),
    available.packages(repos = paste0("file:///", subrepo_dir)),
    get_container_cran_packages_available()
  )

  deps_tarballs <- vapply(
    deps,
    function(dep) build_package(dep, build, container, package_dir,
                                available_packages),
    character(1)
  )

  package_tarball <- build_package(package, build, container, package_dir,
                                   available_packages)

  package_name <- get_package_name(package)

  list(
    package_tarball = c(package_tarball, deps_tarballs),
    package_name = c(package_name, deps)
  )
}

install_in_container <- function(packages, container, subrepo_path) {
  packages <- filter_installed(packages, get_container_packages_installed(),
                               get_container_cran_packages_available())

  if (length(packages) > 0) {
    cat("Installing packages in container:\n", packages)
    packages_string <- paste(capture.output(dput(packages)), collapse = " ")

    install_cmd <- sprintf(
      paste0(
        "install.packages(%s, ",
        "INSTALL_opts = c(\"--no-docs\", \"--no-multiarch\", \"--no-demo\"), ",
        "repos = c(\"file:///%s\", \"cloud.r-project.org\"))"
      ),
      packages_string, subrepo_path
    )

    container(c("Rscript", "-e", install_cmd), FALSE)
  } else {
    cat("No packages to install in container\n")
  }

  invisible()
}

install_packages <- function(packages, container, subrepo_path) {
  if (!is.null(container)) {
    install_in_container(packages, container, subrepo_path)
  } else {
    install.packages(packages)
  }
}

filter_installed <- function(packages, installed_packages,
                             available_packages) {
  installed_packages <- data.frame(installed_packages,
                                   stringsAsFactors = FALSE)
  available_packages <- data.frame(available_packages,
                                   stringsAsFactors = FALSE)

  available_packages$CRAN_Version <- available_packages$Version

  merged_packages_info <- merge(
    installed_packages[c("Package", "Version")],
    available_packages[c("Package", "CRAN_Version")],
    by.x = "Package", by.y = "Package", all.x = TRUE
  )

  merged_packages_info$CRAN_newer <- with(
    merged_packages_info,
    vapply(
      seq_along(CRAN_Version),
      function(x) isTRUE(compareVersion(CRAN_Version[x], Version[x]) == 1),
      logical(1)
    )
  )

  setdiff(
    packages,
    merged_packages_info$Package[!merged_packages_info$CRAN_newer]
  )
}

get_available_packages <- function(container_exec = NULL) {
  if (!is.null(container_exec))
    get_container_cran_packages_available(container_exec)
  else
    available.packages()
}

get_container_cran_packages_available <- function(container_exec) {
  cran_available_path <- file.path(get_gitCRAN_tempdir(), "cran_available.rds")

  if (!file.exists(cran_available_path))
    generate_packages_info(container_exec)

  readRDS(cran_available_path)
}

get_container_packages_installed <- function(container_exec) {
  installed_packages_path <- file.path(get_gitCRAN_tempdir(),
                                       "installed_packages.rds")

  if (!file.exists(installed_packages_path))
    generate_packages_info(container_exec)

  readRDS(installed_packages_path)
}

get_container_gitcran_packages_available <- function(container_exec) {
  gitcran_available_path <- file.path(get_gitCRAN_tempdir(),
                                      "gitcran_available.rds")

  if (!file.exists(gitcran_available_path))
    generate_packages_info(container_exec)

  readRDS(gitcran_available_path)
}

generate_packages_info <- function(container_exec) {
  container_exec(c("Rscript", "/etc/gitCRAN/container_build/packages_info.R"))
}

#' Returns location of built package
build_package <- function(package, build, container, package_dir,
                          available_packages) {
  package <- normalize_package(package, get_package_build_dir(),
                               available_packages)

  if (!is.null(container)) {
    package_tmp <- build_in_container(package, build, container,
                                      available_packages)
  } else {
    devtools::install(package, quiet = TRUE, quick = TRUE)
    package_tmp <- devtools::build(package, binary = build, quiet = TRUE)
  }

  if (!isTRUE(nchar(package_tmp) > 0))
    browser()

  package_name <- gsub("_.+$", "", basename(package_tmp))

  package_version <- get_package_version(package)

  package_tarball <- paste0(package_name, "_", package_version, ".tar.gz")

  archive_existing_package(package_name, package_dir)

  file.copy(package_tmp, file.path(package_dir, package_tarball))
  file.remove(package_tmp)

  file.path(package_dir, package_tarball)
}

archive_existing_package <- function(name, location) {
  packages_file <- file.path(location, "PACKAGES")

  if (!file.exists(packages_file)) {
    stop("PACKAGES file not present in repository packages directory at ",
         location)
  }

  existing_packages <- dir(location, pattern = paste0(name, "_[0-9.]+tar.gz"),
                           full.names = TRUE)

  if (isTRUE(length(existing_packages) > 0)) {
    archive_dir <- file.path(location, "Archive", name)
    dir.create(archive_dir, showWarnings = FALSE, recursive = TRUE)

    file.copy(existing_packages, archive_dir, overwrite = TRUE)
    file.remove(existing_packages)
    git2r::add(repo = file.path(location, "../../"), path = existing_packages)
  } else {
    cat("Preexisting", name, "not found in repository, no archiving needed.\n")
  }

  invisible()
}

build_in_container <- function(package, build, container, available_packages) {
  normalized_package <- normalize_package(package, get_package_build_dir(),
                                          available_packages)

  # install_cmd <- sprintf("devtools::install('%s', quick = TRUE, quiet = TRUE)",
  #                        normalized_package)

  # container$exec(c("R", "-e", install_cmd))

  build_cmd <- sprintf("devtools::build('%s', binary = %s, quiet = TRUE)",
                       normalized_package, build)
  package_path_file <- file.path(get_package_build_dir(), "package_path")
  container_cmd <- sprintf("writeLines(%s, '%s')", build_cmd, package_path_file)
  container(c("R", "-e", container_cmd))

  package_path <- readLines(package_path_file)[1]
  file.remove(package_path_file)
  package_path
}

make_container_exec <- function(docker_client, image, gitCRAN_tempdir,
                                repo_dir, lib_dir = NULL,
                                update_image = FALSE) {
  function(command, stream = stdout()) {
    container_exec(docker_client, image, command, gitCRAN_tempdir,
                   repo_dir, lib_dir = lib_dir, update_image = update_image,
                   stream = stream)
  }
}

container_exec <- function(docker_client, image, command, gitCRAN_tempdir,
                           repo_dir, lib_dir = NULL, update_image = FALSE,
                           stream = stdout()) {
  local_images <- vapply(
    Filter(function(x) length(x) > 0,
           docker_client$image$list()$repo_tags),
    I,
    character(1)
  )

  if (!(image %in% local_images))
    docker_client$image$pull(image)
  else if (isTRUE(update_image))
    tryCatch({
      docker_client$image$pull(image)
    }, error = function(e) {
      cat("Error updating image, using the local image: \n", e)
    })

  if (!is.null(lib_dir))
    lib_dir <- paste0(lib_dir, ":/opt/Rlib")

  container <- docker_client$container$run(
    image = image,
    cmd = command,
    stream = stream,
    volumes = c(
      paste0(gitCRAN_tempdir, ":", gitCRAN_tempdir),
      paste0(gitCRAN_tempdir, ":/opt/gitCRAN"),
      paste0(repo_dir, ":", repo_dir),
      paste0(system.file(package = "gitCRAN"), ":/etc/gitCRAN"),
      lib_dir
    )
  )

  on.exit({
    container$container$remove(force = TRUE)
  })
}