#! /usr/bin/env nix-shell
#! nix-shell -i python3 -p python3 python3.pkgs.packaging python3.pkgs.requests python3.pkgs.xmltodict
import json
import pathlib
import logging
import requests
import subprocess
import sys
import xmltodict
import itertools as it
from packaging import version
from pprint import pprint

updates_url = "https://www.jetbrains.com/updates/updates.xml"
current_path = pathlib.Path(__file__).parent
versions_file_path = current_path.joinpath("versions.json").resolve()
fromVersions = {}
toVersions = {}

logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)


def one_or_more(x):
    return x if isinstance(x, list) else [x]


def download_products():
    logging.info("Checking for updates from %s", updates_url)
    updates_response = requests.get(updates_url)
    updates_response.raise_for_status()
    root = xmltodict.parse(updates_response.text)
    products = root["products"]["product"]
    by_product = {
        product["@name"]: product
        for product in products
        if "channel" in product
    }
    by_channel = {
        channel["@name"]: product
        for product in products
        if "channel" in product
        for channel in one_or_more(product["channel"])
    }

    return {**by_product, **by_channel}


def build_order(pair):
    channel_name, build = pair
    base_number = build['@number']
    build_number = build["@fullNumber"] if "@fullNumber" in build else base_number
    return (version.parse(base_number), version.parse(build_number))


def latest_build(product):
    builds = [
        (channel['@name'], build)
        for channel in one_or_more(product['channel'])
        for build in one_or_more(channel['build'])
    ]
    return max(builds, key=build_order)


def download_sha256(url):
    url = f"{url}.sha256"
    download_response = requests.get(url)
    download_response.raise_for_status()
    return download_response.content.decode('UTF-8').split(' ')[0]


all_data = download_products()


def update_product(name, product):
    last_channel = product["update-channel"]
    update_key = product.get('name', last_channel)
    logging.info("Updating %s using key %s (last channel was `%s`)", name, update_key, last_channel)
    product_info = all_data.get(update_key)
    if product_info is None:
        logging.error("Failed to find product %s.", update_key)
        logging.error("Check that the update-channel in %s matches the name in %s", versions_file_path, updates_url)
    else:
        try:
            channel_name, build = latest_build(product_info)
            new_version = build["@version"]
            new_build_number = build["@fullNumber"]
            if "EAP" not in channel_name:
                version_or_build_number = new_version
            else:
                version_or_build_number = new_build_number
            version_number = new_version.split(' ')[0]
            download_url = product["url-template"].format(version=version_or_build_number, versionMajorMinor=version_number)
            product["url"] = download_url
            if "sha256" not in product or product.get("build_number") != new_build_number:
                fromVersions[name] = product["version"]
                toVersions[name] = new_version
                logging.info("Found a newer version %s with build number %s.", new_version, new_build_number)
                product['update-channel'] = channel_name
                product["version"] = new_version
                product["build_number"] = new_build_number
                product["sha256"] = download_sha256(download_url)
            else:
                logging.info("Already at the latest version %s with build number %s.", new_version, new_build_number)
        except Exception as e:
            logging.exception("Update failed:", exc_info=e)
            logging.warning("Skipping %s due to the above error.", name)
            logging.warning("It may be out-of-date. Fix the error and rerun.")


def update_products(products):
    for name, product in products.items():
        update_product(name, product)


def main():
    with open(versions_file_path, "r") as versions_file:
        versions = json.load(versions_file)

    for products in versions.values():
        update_products(products)

    with open(versions_file_path, "w") as versions_file:
        json.dump(versions, versions_file, indent=2)
        versions_file.write("\n")

    if len(toVersions) == 0:
        # No Updates found
        return

    lowestVersion = min(fromVersions.values())
    highestVersion = max(toVersions.values())
    commitMessage = f"chore(ide): Update JetBrains IDEs {lowestVersion} -> {highestVersion}"
    commitMessage += "\n\n"

    for name in toVersions.keys():
        commitMessage += f"jetbrains.{name}: {fromVersions[name]} -> {toVersions[name]}\n"

    # Commit the result
    logging.info("#### Committing changes... ####")
    subprocess.run(['git', 'commit', f'-m{commitMessage}', '--', f'{versions_file_path}'], check=True)

    logging.info("#### Updating plugins ####")
    plugin_script = current_path.joinpath("plugins/update_plugins.py").resolve()
    subprocess.call(plugin_script)

if __name__ == '__main__':
    main()
