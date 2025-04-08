# -*- coding: utf-8 -*-
"""
make-sitrep.py

Author: Joel McCune
Date: 2025-04-08
Description: Script to generate a weekly situational report (sitrep).
"""

from datetime import date, timedelta
from pathlib import Path

def main():
    """Main function to execute the script."""
    # Get the current date
    today = date.today()

    # get the date for this coming Friday
    if today <= 4:
        friday = today + timedelta(4 - today.weekday())
    else:
        friday = today + timedelta(6 - today.weekday())

    # Text for report header idnetifying date for mkdocs
    header_dt_str = friday.strftime("%Y-%m-%d")
    header = (
        "---\n"
        f"date: {header_dt_str}\n"
        "---\n\n"
    )

    # Text for report body
    body_dt_str = friday.strftime('%d %b %Y')
    body = (
        f"# SitRep {body_dt_str}\n\n"
        "## 1 - Critical Timebound Completed\n\n-\n\n"
        "## 2 - Other High Importance Completed\n\n-\n\n"
        "## 3 - Shifting Priorities\n\n-\n\n"
        "#### Escalate\n\n-\n\n"
        "#### Diminish\n\n-\n\n"
    )

    # Combine header and content
    full_text = header + body

    # get the posts directory to put new report into
    posts_dir = Path(__file__).parent.parent / "docs" / "sitreps" / "posts"

    # create the full path to where the report will be saved
    file_dt_str = friday.strftime('%Y%m%d')
    report_path = posts_dir / f"sitrep_{file_dt_str}.md"

    # write the report to the file
    with open(report_path, mode="w", encoding="utf-8") as report_file:
        report_file.write(full_text)

if __name__ == "__main__":
    main()