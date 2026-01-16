
#!/usr/bin/env python3
"""
Use to detect strings that cause "Invalid IPv6 URL" errors in Zensical.

This script monkeypatches urllib.parse.urlsplit and urlparse to add debug logging when such errors occur.

Use:

``` terminal
python debug_zensical.py build
python debug_zensical.py serve
```


"""
import sys, urllib.parse as _up

# Keep originals
_orig_urlsplit = _up.urlsplit
_orig_urlparse = _up.urlparse

def _wrapped_urlsplit(url, scheme='', allow_fragments=True):
    try:
        return _orig_urlsplit(url, scheme, allow_fragments)
    except ValueError as e:
        if str(e) == "Invalid IPv6 URL":
            print("\n=== DEBUG: Invalid IPv6 URL while splitting ===", file=sys.stderr)
            print(f"URL: {url!r}", file=sys.stderr)
        raise

def _wrapped_urlparse(url, scheme='', allow_fragments=True):
    try:
        return _orig_urlparse(url, scheme, allow_fragments)
    except ValueError as e:
        if str(e) == "Invalid IPv6 URL":
            print("\n=== DEBUG: Invalid IPv6 URL while parsing ===", file=sys.stderr)
            print(f"URL: {url!r}", file=sys.stderr)
        raise

# Monkeypatch
_up.urlsplit = _wrapped_urlsplit
_up.urlparse = _wrapped_urlparse

# (Optional) add lightweight hooks around Zensical’s config/markdown to log files being processed
# See approach similar to this community gist that wraps Zensical functions:
# https://gist.github.com/kamilkrzyskow/72c6ec3093e48132ead9469558e144c2
try:
    import zensical.markdown as _md
    _orig_render = _md.render
    def render_with_log(content: str, path: str):
        try:
            return _orig_render(content, path)
        except Exception as ex:
            print(f"\n=== DEBUG: Exception while rendering {path} ===", file=sys.stderr)
            raise
    _md.render = render_with_log
except Exception:
    pass

# Hand off to Zensical CLI
import zensical.main as _main
_main.cli()
