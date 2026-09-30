"""Configure the generated Expo app to use the shared local planner server."""

import argparse
import json
from pathlib import Path
from urllib.parse import urlparse


def main() -> None:
    """Set the API URL in the generated Expo configuration."""

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url", nargs="?", default="http://127.0.0.1:8000")
    args = parser.parse_args()
    parsedUrl = urlparse(args.url)

    if parsedUrl.scheme not in {"http", "https"} or not parsedUrl.netloc:
        parser.error("URL must include http:// or https:// and a host")

    configPath = Path(__file__).resolve().parents[1] / ".jac/mobile-rn/app.json"

    if not configPath.exists():
        parser.error(
            "Run jac build --platform ios mobile first to generate the Expo app"
        )

    config = json.loads(configPath.read_text())
    config["expo"].setdefault("extra", {})["apiBaseUrl"] = args.url.rstrip("/")
    configPath.write_text(json.dumps(config, indent=2) + "\n")
    injectionPath = configPath.with_name("__jacApiBase.js")
    injectionPath.write_text(
        "globalThis.__JAC_API_BASE_URL__ = " + json.dumps(args.url.rstrip("/")) + ";\n"
    )
    print(f"Mobile API: {config['expo']['extra']['apiBaseUrl']}")


if __name__ == "__main__":
    main()
