# -*- coding: utf-8 -*-
"""
sync_local_to_portal.py

Author: Joel McCune
Date: 2026-04-24

Description:
    Crawls a local directory for files of specified types and compares them
    against items stored in an ArcGIS Enterprise Portal. Any files found
    locally that do NOT already exist in the Portal (matched by filename
    without extension, case-insensitively) are uploaded automatically.

    This script is designed to be run from the command line OR imported as
    a module and called from another Python script.

Prerequisites:
    The ArcGIS API for Python must be installed in the active environment.
    If you are using the project conda environment, install it with:

        conda install -c esri arcgis

    or add "arcgis" to your environment.yml and recreate the environment.

Usage (command line):
    # Upload all PDFs from a local folder using a saved Portal profile
    python sync_local_to_portal.py /path/to/local/folder --profile my_portal

    # Upload PDFs AND CSVs, drop them in a specific Portal subfolder
    python sync_local_to_portal.py /path/to/local/folder \\
        --profile my_portal \\
        --extensions .pdf .csv \\
        --portal-folder "My Uploaded Documents"

    # Turn on verbose (DEBUG) logging to see every detail
    python sync_local_to_portal.py /path/to/local/folder \\
        --profile my_portal \\
        --verbose

Notes on Portal profiles:
    A "profile" is a saved set of ArcGIS connection credentials stored on your
    machine. You can create one interactively once, and then reuse it by name:

        from arcgis.gis import GIS
        gis = GIS("https://your-portal-url.com/portal", "username", "password",
                  profile="my_portal")

    After running the above, future connections can use:
        gis = GIS(profile="my_portal")

    If the profile name you provide is not found on this machine, the script
    will tell you exactly what went wrong and how to fix it.
"""

import argparse
import logging
import sys
from pathlib import Path
from typing import Optional

# check to ensure the arcgis package is available before we import it, so we can 
# provide a clear error message if it's missing (instead of a raw ImportError traceback)
try:
    from arcgis.gis import GIS
except ImportError:
    raise ImportError(
        "Error: The 'arcgis' package is not installed in the active Python environment.\n"
        "Please install it with 'conda install -c esri arcgis' or add it to your "
        "environment.yml and recreate the environment. For more details, see the "
        "prerequisites section in the script's docstring."
    )

# ---------------------------------------------------------------------------
# Extension → ArcGIS Portal item type mapping
# ---------------------------------------------------------------------------
# This dictionary maps common file extensions to the item type string that
# ArcGIS Enterprise expects when you upload content. Add entries here if you
# need to support additional file types in the future.
EXTENSION_TO_ITEM_TYPE: dict[str, str] = {
    ".pdf": "PDF",
    ".csv": "CSV",
    ".xls": "Microsoft Excel",
    ".xlsx": "Microsoft Excel",
}

# ---------------------------------------------------------------------------
# Logging configuration
# ---------------------------------------------------------------------------
# We set up a module-level logger. The calling code (or the CLI entry point
# below) is responsible for configuring the log level and handlers.
logger = logging.getLogger(__name__)


# ===========================================================================
# Phase 1 — Authentication
# ===========================================================================

def _connect_to_portal(gis: Optional[GIS] = None, profile: Optional[str] = None) -> GIS:
    """
    Return an authenticated ArcGIS GIS connection object.

    This helper accepts either:
      - A pre-initialized GIS object (useful when calling from another script)
      - A profile name string (useful from the CLI or when you have saved
        credentials via the ArcGIS API for Python profile system)

    Parameters
    ----------
    gis : arcgis.gis.GIS, optional
        An already-authenticated GIS object. If provided, it is returned
        immediately without any further authentication.
    profile : str, optional
        The name of a saved ArcGIS profile on this machine. The profile must
        have been created previously (see module docstring for instructions).

    Returns
    -------
    arcgis.gis.GIS
        An authenticated connection to an ArcGIS Enterprise Portal.

    Raises
    ------
    ValueError
        If neither `gis` nor `profile` is provided.
    SystemExit
        If a profile name is given but cannot be found or loaded on this
        machine. We exit with a helpful message rather than a raw traceback.
    """
    # --- Case 1: caller already has an authenticated GIS object ---
    # Import here so the error is raised at call-time (not at module import),
    # making it easier to diagnose a missing arcgis package.

    if gis is not None:
        # Verify it really is a GIS instance so we catch mistakes early.
        if not isinstance(gis, GIS):
            raise TypeError(
                f"Expected an arcgis.gis.GIS object, got {type(gis).__name__}. "
                "Please pass a properly initialized GIS object."
            )
        logger.info(f"Using the provided GIS connection to: {gis.url}")
        return gis

    # --- Case 2: caller provided a profile name ---
    if profile is not None:
        logger.info(
            f"Connecting to ArcGIS Enterprise using saved profile: '{profile}'"
        )
        try:
            # GIS(profile=...) reads stored credentials from the local
            # keyring/profile store. If the profile does not exist it raises.
            connected_gis = GIS(profile=profile)
            logger.info(
                f"Successfully connected to Portal at: {connected_gis.url}  (logged in as: {connected_gis.users.me.username})"
            )
            return connected_gis

        except Exception as exc:
            # Provide a clear, actionable error message for the client.
            # The raw exception is attached so a developer can dig deeper.
            logger.error(
                f"Could not connect using profile '{profile}'. "
                "The profile was not found on this machine or the saved "
                "credentials are no longer valid.\n\n"
                "To create a profile, run the following Python code once:\n\n"
                "    from arcgis.gis import GIS\n"
                "    gis = GIS(\n"
                "        'https://your-portal-url.com/portal',\n"
                "        'your_username',\n"
                "        'your_password',\n"
                f"        profile='{profile}'\n"
                "    )\n\n"
                f"Original error: {exc}",
            )
            sys.exit(1)

    # --- Case 3: nothing was provided — tell the user what to do ---
    raise ValueError(
        "You must provide either a pre-initialized GIS object (gis=...) "
        "or a saved profile name (profile='...'). "
        "Neither was supplied."
    )


# ===========================================================================
# Phase 2 — Local directory crawl
# ===========================================================================

def _crawl_local_directory(
    local_dir: str | Path,
    file_extensions: list[str] | None = None,
) -> list[Path]:
    """
    Walk a local directory (recursively) and return a list of files whose
    extension matches the requested types.

    Parameters
    ----------
    local_dir : str or Path
        The root directory to search. All subdirectories are included.
    file_extensions : list of str, optional
        Extensions to include, e.g. ['.pdf', '.csv']. Case-insensitive.
        A leading dot is added automatically if missing (so 'pdf' → '.pdf').
        Defaults to ['.pdf'] if not provided.

    Returns
    -------
    list of pathlib.Path
        All matching files found beneath local_dir.

    Raises
    ------
    NotADirectoryError
        If local_dir does not exist or is not a directory.
    """
    # --- Normalize the directory path ---
    local_dir = Path(local_dir)
    logger.debug("Resolving local directory path: %s", local_dir)

    if not local_dir.exists():
        raise NotADirectoryError(
            f"The directory '{local_dir}' does not exist. "
            "Please check the path and try again."
        )
    if not local_dir.is_dir():
        raise NotADirectoryError(
            f"'{local_dir}' is a file, not a directory. "
            "Please provide the path to a folder."
        )

    # --- Normalize extensions ---
    # Default to PDF if the caller did not specify anything.
    if file_extensions is None:
        file_extensions = [".pdf"]
        logger.info("No file extensions specified — defaulting to: .pdf")

    # Ensure every extension starts with a dot and is lowercase so comparisons
    # are consistent regardless of how the user typed them.
    normalized_extensions: set[str] = set()
    for ext in file_extensions:
        ext = ext.strip().lower()
        if not ext.startswith("."):
            ext = "." + ext
        normalized_extensions.add(ext)

    logger.info(
        "Crawling directory: %s  (looking for extensions: %s)",
        local_dir,
        ", ".join(sorted(normalized_extensions)),
    )

    # --- Walk the directory tree ---
    # Path.rglob("*") returns every file and folder recursively.
    # We filter to files only and check the extension.
    matched_files: list[Path] = []

    for item in sorted(local_dir.rglob("*")):
        if not item.is_file():
            # Skip subdirectory entries — we only want files.
            continue

        if item.suffix.lower() in normalized_extensions:
            logger.debug("  Found matching file: %s", item)
            matched_files.append(item)
        else:
            logger.debug("  Skipping (wrong type): %s", item)

    logger.info(
        "Crawl complete. Found %d matching file(s) in '%s'.",
        len(matched_files),
        local_dir,
    )

    return matched_files


# ===========================================================================
# Phase 3 — Portal item inventory
# ===========================================================================

def _get_portal_items(
    gis: GIS,
    file_extensions: list[str] | None = None,
) -> dict[str, object]:
    """
    Query the authenticated user's content in ArcGIS Enterprise and build a
    fast lookup dictionary keyed by item title (lowercased, no extension).

    Only item types that correspond to the requested file extensions are
    included in the results. This avoids false matches with unrelated content.

    Parameters
    ----------
    gis : arcgis.gis.GIS
        An authenticated GIS connection.
    file_extensions : list of str, optional
        Same extension list passed to _crawl_local_directory. Used to filter
        Portal items to only the relevant types. Defaults to ['.pdf'].

    Returns
    -------
    dict mapping str → arcgis.gis.Item
        Keys are item titles lowercased for case-insensitive lookup.
        Values are the full ArcGIS Item objects (useful for logging item IDs).
    """
    # --- Determine which Portal item types we care about ---
    if file_extensions is None:
        file_extensions = [".pdf"]

    # Normalize extensions the same way as in _crawl_local_directory.
    normalized_extensions: set[str] = set()
    for ext in file_extensions:
        ext = ext.strip().lower()
        if not ext.startswith("."):
            ext = "." + ext
        normalized_extensions.add(ext)

    # Map each requested extension to its Portal item type string.
    # Skip extensions we do not have a mapping for (log a warning).
    relevant_item_types: set[str] = set()
    for ext in normalized_extensions:
        item_type = EXTENSION_TO_ITEM_TYPE.get(ext)
        if item_type:
            relevant_item_types.add(item_type)
        else:
            logger.warning(
                "No Portal item type mapping for extension '%s'. "
                "Items of this type will not be searched in the Portal. "
                "To add support, update the EXTENSION_TO_ITEM_TYPE dict "
                "at the top of this script.",
                ext,
            )

    logger.info(
        "Searching Portal for item types: %s",
        ", ".join(sorted(relevant_item_types)) if relevant_item_types else "(none)",
    )

    # --- Search the Portal ---
    # We search only content owned by the currently logged-in user.
    # This prevents false-positive matches with items shared to us by others.
    username = gis.users.me.username
    search_query = f"owner:{username}"

    logger.info(
        "Querying Portal for all items owned by '%s' (max 10,000)…", username
    )

    # max_items=10000 fetches up to 10,000 items. If your Portal has more than
    # this, you would need to paginate. For most use cases 10,000 is plenty.
    all_owned_items = gis.content.search(query=search_query, max_items=10_000)

    logger.info(
        "Portal returned %d total owned item(s). Filtering to relevant types…",
        len(all_owned_items),
    )

    # --- Filter to relevant types and build the lookup dict ---
    # Key: title.casefold() so comparisons are case-insensitive.
    # Value: the full Item object so we can log the item ID later.
    portal_index: dict[str, object] = {}

    for item in all_owned_items:
        if item.type in relevant_item_types:
            key = item.title.casefold()
            portal_index[key] = item
            logger.debug(
                "  Portal item: '%s'  (type: %s, id: %s)",
                item.title,
                item.type,
                item.id,
            )

    logger.info(
        "Portal inventory complete. Found %d item(s) matching the "
        "requested type(s).",
        len(portal_index),
    )

    return portal_index


# ===========================================================================
# Phase 4 — Compare and upload
# ===========================================================================

def _compare_and_upload(
    local_files: list[Path],
    portal_index: dict[str, object],
    gis: GIS,
    portal_folder: str | None = None,
) -> dict[str, list[Path]]:
    """
    Compare local files against the Portal inventory and upload any that are
    missing.

    A file is considered to already exist in the Portal if the Portal has any
    item whose title (lowercased, stripped of extension) exactly matches the
    local filename stem (also lowercased).

    Parameters
    ----------
    local_files : list of Path
        Files discovered by _crawl_local_directory.
    portal_index : dict
        Lookup dict from _get_portal_items (keys are lowercased titles).
    gis : arcgis.gis.GIS
        Authenticated GIS connection.
    portal_folder : str, optional
        Name of a subfolder inside the user's Portal content where items will
        be placed. If the folder does not exist, ArcGIS will create it.
        If None, items land in the user's root content folder.

    Returns
    -------
    dict with keys 'uploaded', 'skipped', 'failed'
        Each value is a list of Path objects (or (Path, exception) tuples
        for 'failed') so the caller can build a summary report.
    """
    results: dict[str, list[Path]] = {
        "uploaded": [],
        "skipped": [],
        "failed": [],
    }

    if not local_files:
        logger.info("No local files to process. Nothing to do.")
        return results

    logger.info(
        "Comparing %d local file(s) against the Portal inventory…",
        len(local_files),
    )

    for file_path in local_files:
        # Build the comparison key: filename without extension, all lowercase.
        # Example: "Annual_Report_2025.PDF" → "annual_report_2025"
        comparison_key = file_path.stem.casefold()

        logger.debug(
            "Checking local file: '%s'  (lookup key: '%s')",
            file_path.name,
            comparison_key,
        )

        # --- Check if this file already exists in the Portal ---
        if comparison_key in portal_index:
            existing_item = portal_index[comparison_key]
            logger.debug(
                "  SKIP — already in Portal: '%s' (id: %s)",
                existing_item.title,
                existing_item.id,
            )
            results["skipped"].append(file_path)
            continue  # Move on to the next file.

        # --- File is not in the Portal — upload it ---
        logger.info(
            "  UPLOAD — '%s' not found in Portal. Uploading…", file_path.name
        )

        # Look up the item type string for this file's extension.
        # We already validated extensions earlier, but be defensive here.
        item_type = EXTENSION_TO_ITEM_TYPE.get(file_path.suffix.lower())
        if item_type is None:
            logger.warning(
                "  SKIP (unknown type) — No Portal item type mapping for "
                "extension '%s'. Skipping '%s'.",
                file_path.suffix,
                file_path.name,
            )
            results["skipped"].append(file_path)
            continue

        # Build the item properties dictionary that Portal expects.
        # 'title' is what users will see in Portal content; we use the
        # filename stem (preserving original capitalization for readability).
        # 'type' must match one of the Portal's accepted item type strings.
        item_properties = {
            "title": file_path.stem,
            "type": item_type,
        }

        logger.debug(
            "  Uploading with properties: %s  (file: %s)",
            item_properties,
            file_path,
        )

        try:
            # gis.content.add() sends the file to the Portal.
            # 'folder' is the Portal subfolder; None means the root folder.
            uploaded_item = gis.content.add(
                item_properties=item_properties,
                data=str(file_path),
                folder=portal_folder,
            )

            logger.info(
                "  SUCCESS — Uploaded '%s' → Portal item id: %s  (type: %s)",
                file_path.name,
                uploaded_item.id,
                uploaded_item.type,
            )
            results["uploaded"].append(file_path)

        except Exception as exc:
            # Catch any upload error so one bad file does not abort the whole
            # run. We log the full error and continue with the next file.
            logger.error(
                "  FAILED — Could not upload '%s'. Error: %s",
                file_path.name,
                exc,
            )
            results["failed"].append((file_path, exc))

    return results


# ===========================================================================
# Top-level public function (use this when importing as a module)
# ===========================================================================

def sync_local_to_portal(
    local_dir: str | Path,
    gis: Optional[GIS] = None,
    profile: Optional[str] = None,
    file_extensions: Optional[list[str]] = None,
    portal_folder: Optional[str] = None,
) -> dict[str, list[Path]]:
    """
    Compare a local directory against an ArcGIS Enterprise Portal and upload
    any files that are missing from the Portal.

    This is the main entry point when using this script as a Python module.
    For command-line usage, see the module docstring at the top of this file.

    Parameters
    ----------
    local_dir : str or Path
        Path to the local directory to crawl. All subdirectories are included.
    gis : arcgis.gis.GIS, optional
        A pre-initialized, authenticated GIS object. Provide this OR profile.
    profile : str, optional
        Name of a saved ArcGIS connection profile on this machine. Provide
        this OR gis.
    file_extensions : list of str, optional
        File extensions to consider, e.g. ['.pdf', '.csv']. Defaults to
        ['.pdf'] if not specified.
    portal_folder : str, optional
        Portal subfolder to upload new items into. If None, items go to the
        user's root Portal folder.

    Returns
    -------
    dict with keys 'uploaded', 'skipped', 'failed'
        Summary of what happened to each file found locally.

    Example
    -------
    >>> from arcgis.gis import GIS
    >>> gis = GIS(profile="my_portal")
    >>> results = sync_local_to_portal(
    ...     local_dir="/data/reports",
    ...     gis=gis,
    ...     file_extensions=[".pdf"],
    ...     portal_folder="Annual Reports",
    ... )
    >>> print(f"Uploaded: {len(results['uploaded'])}")
    """
    # --- Step 1: Connect to Portal ---
    logger.info("=" * 60)
    logger.info("Step 1 of 4: Connecting to ArcGIS Enterprise Portal")
    logger.info("=" * 60)
    connected_gis = _connect_to_portal(gis=gis, profile=profile)

    # --- Step 2: Crawl the local directory ---
    logger.info("=" * 60)
    logger.info("Step 2 of 4: Crawling local directory for files")
    logger.info("=" * 60)
    local_files = _crawl_local_directory(
        local_dir=local_dir,
        file_extensions=file_extensions,
    )

    # --- Step 3: Inventory Portal content ---
    logger.info("=" * 60)
    logger.info("Step 3 of 4: Inventorying existing Portal content")
    logger.info("=" * 60)
    portal_index = _get_portal_items(
        gis=connected_gis,
        file_extensions=file_extensions,
    )

    # --- Step 4: Compare and upload ---
    logger.info("=" * 60)
    logger.info("Step 4 of 4: Comparing local files to Portal and uploading")
    logger.info("=" * 60)
    results = _compare_and_upload(
        local_files=local_files,
        portal_index=portal_index,
        gis=connected_gis,
        portal_folder=portal_folder,
    )

    return results


# ===========================================================================
# CLI entry point
# ===========================================================================

def _build_arg_parser() -> argparse.ArgumentParser:
    """Build and return the argument parser for the CLI."""
    parser = argparse.ArgumentParser(
        prog="sync_local_to_portal",
        description=(
            "Compare a local directory against an ArcGIS Enterprise Portal "
            "and upload any files that are not already present."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Examples:\n"
            "  # Upload PDFs from a local folder\n"
            "  python sync_local_to_portal.py /data/reports --profile my_portal\n\n"
            "  # Upload PDFs and CSVs into a specific Portal subfolder\n"
            "  python sync_local_to_portal.py /data/reports \\\n"
            "      --profile my_portal \\\n"
            "      --extensions .pdf .csv \\\n"
            "      --portal-folder 'My Documents'\n\n"
            "  # Show every detail (DEBUG logging)\n"
            "  python sync_local_to_portal.py /data/reports \\\n"
            "      --profile my_portal --verbose\n"
        ),
    )

    # --- Required positional argument ---
    parser.add_argument(
        "local_dir",
        metavar="LOCAL_DIR",
        help=(
            "Path to the local directory to crawl. "
            "All subdirectories are included in the search."
        ),
    )

    # --- Auth argument ---
    parser.add_argument(
        "--profile",
        metavar="PROFILE_NAME",
        default=None,
        help=(
            "Name of a saved ArcGIS connection profile on this machine. "
            "Create a profile once with: "
            "GIS('https://portal-url/portal', 'user', 'pass', profile='name'). "
            "The script will exit with a clear error if the profile is not found."
        ),
    )

    # --- File types argument ---
    parser.add_argument(
        "--extensions",
        metavar="EXT",
        nargs="+",
        default=[".pdf"],
        help=(
            "One or more file extensions to look for, e.g. .pdf .csv .xlsx. "
            "Include the leading dot. "
            "Default: .pdf"
        ),
    )

    # --- Portal folder argument ---
    parser.add_argument(
        "--portal-folder",
        metavar="FOLDER_NAME",
        default=None,
        dest="portal_folder",
        help=(
            "Name of a subfolder in your Portal content where uploaded items "
            "will be placed. If the folder does not exist, Portal creates it. "
            "If omitted, items go to your root Portal content folder."
        ),
    )

    # --- Verbosity flag ---
    parser.add_argument(
        "--verbose",
        action="store_true",
        default=False,
        help=(
            "Enable verbose (DEBUG) logging. Shows every file checked, every "
            "Portal item inspected, and detailed upload information. "
            "Useful for troubleshooting."
        ),
    )

    return parser


def main() -> None:
    """
    CLI entry point. Parse arguments, configure logging, run the sync, and
    print a human-readable summary when done.
    """
    parser = _build_arg_parser()
    args = parser.parse_args()

    # --- Configure logging ---
    # Use DEBUG if --verbose was passed, otherwise INFO.
    # Format: timestamp — level — message
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(
        level=log_level,
        format="%(asctime)s — %(levelname)-8s — %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        stream=sys.stdout,
    )

    logger.info("sync_local_to_portal — starting")
    logger.info("  Local directory : %s", args.local_dir)
    logger.info("  Profile         : %s", args.profile or "(none provided)")
    logger.info("  Extensions      : %s", ", ".join(args.extensions))
    logger.info("  Portal folder   : %s", args.portal_folder or "(root folder)")
    logger.info("  Log level       : %s", "DEBUG (verbose)" if args.verbose else "INFO")

    # --- Require a profile on the CLI ---
    # When running from the command line we can only accept a profile name
    # (there is no way to pass a GIS object as a CLI argument).
    if args.profile is None:
        parser.error(
            "You must provide --profile with the name of a saved ArcGIS "
            "connection profile. Run with --help for usage details."
        )

    # --- Run the sync ---
    results = sync_local_to_portal(
        local_dir=args.local_dir,
        profile=args.profile,
        file_extensions=args.extensions,
        portal_folder=args.portal_folder,
    )

    # --- Print the summary ---
    # Present a clear, easy-to-read summary so the client can see at a glance
    # what happened without having to read through the full log output.
    uploaded_count = len(results["uploaded"])
    skipped_count = len(results["skipped"])
    failed_count = len(results["failed"])
    total_count = uploaded_count + skipped_count + failed_count

    print()
    print("=" * 60)
    print("  SYNC COMPLETE — SUMMARY")
    print("=" * 60)
    print(f"  Total local files found   : {total_count}")
    print(f"  Already in Portal (skipped): {skipped_count}")
    print(f"  Successfully uploaded      : {uploaded_count}")
    print(f"  Failed to upload           : {failed_count}")
    print("=" * 60)

    if uploaded_count > 0:
        print("\nUploaded files:")
        for file_path in results["uploaded"]:
            print(f"  + {file_path.name}")

    if failed_count > 0:
        print("\nFailed uploads (see log above for details):")
        for file_path, exc in results["failed"]:
            print(f"  ✗ {file_path.name}  →  {exc}")

    print()

    # Exit with a non-zero code if any uploads failed, so automated tooling
    # (e.g. shell scripts, CI pipelines) can detect a partial failure.
    if failed_count > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
