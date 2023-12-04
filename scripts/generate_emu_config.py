#steam ids with public profiles that own a lot of games
TOP_OWNER_IDS = [76561198028121353, 76561198001237877, 76561198355625888, 76561198001678750, 76561198237402290, 76561197979911851, 76561198152618007, 76561197969050296, 76561198213148949, 76561198037867621, 76561198108581917]

from steam.enums.common import EResult
from steam.webapi import WebAPI
import os
import sys
import json
import urllib.request
import urllib.error
import threading
import queue
import requests

THREADS = 20

prompt_for_unavailable = True

web = None
with open(".secret","r") as f:
    web = WebAPI(f.read().strip())

if len(sys.argv) < 2:
    print("\nUsage: {} appid appid appid etc..\n\nExample: {} 480\n".format(sys.argv[0], sys.argv[0]))
    exit(1)

appids = []
for id in sys.argv[1:]:
    appids +=  [int(id)]

def get_stats_schema(game_id):
    return web.call("ISteamUserStats.GetSchemaForGame", appid=game_id)

def download_achievement_images(game_id, image_names, output_folder):
    q = queue.Queue()

    def downloader_thread():
        while True:
            name = q.get()
            if name is None:
                q.task_done()
                return
            try:
                with urllib.request.urlopen(name) as response:
                    image_data = response.read()
                    with open(os.path.join(output_folder, name.split("/")[-1]), "wb") as f:
                        f.write(image_data)
            except urllib.error.HTTPError as e:
                print("HTTPError downloading", name, e.code)
            except urllib.error.URLError as e:
                print("URLError downloading", name, e.code)
            q.task_done()

    num_threads = THREADS
    for i in range(num_threads):
        threading.Thread(target=downloader_thread, daemon=True).start()

    for name in image_names:
        q.put(name)
    q.join()

    for i in range(num_threads):
        q.put(None)
    q.join()


def generate_achievement_stats(game_id, output_directory):
    achievements = None
    achievement_images_dir = os.path.join(output_directory, "achievement_images")
    images_to_download = []
    out = get_stats_schema(game_id)["game"]
    if out:
        achievements = out["availableGameStats"]["achievements"]
        for ach in achievements:
            ach["displayName"] = {"english": ach["displayName"]}
            ach["hidden"] = f"{ach['hidden']}"
            if "description" in ach:
                ach["description"] = {"english": ach["description"]}
            else:
                ach["description"] = {"english": "This achievement is hidden"}
            if "icon" in ach:
                images_to_download.append(ach["icon"])
                ach["icon"] = ach["icon"].split('/')[-1]
            if "icongray" in ach:
                images_to_download.append(ach["icongray"])
                ach["icon_gray"] = ach.pop("icongray").split('/')[-1]

                
    if (len(images_to_download) > 0):
        if not os.path.exists(achievement_images_dir):
            os.makedirs(achievement_images_dir)
        download_achievement_images(game_id, images_to_download, achievement_images_dir)
    return achievements

def get_dlc(appid):
    x = requests.get(f"https://store.steampowered.com/api/dlcforapp?appid={appid}").json()
    if x["status"] != 1: return []
    l = []
    for dlc in x["dlc"]:
        l.append(f"{dlc['id']}={dlc['name']}")
    return l

for appid in appids:
    backup_dir = os.path.join("backup","{}".format(appid))
    out_dir = os.path.join("{}".format( "{}_output".format(appid)), "steam_settings")

    if not os.path.exists(backup_dir):
        os.makedirs(backup_dir)

    if not os.path.exists(out_dir):
        os.makedirs(out_dir)

    print("outputting config to", out_dir)

    achievements = generate_achievement_stats(appid, out_dir)
    with open(os.path.join(out_dir, "achievements.json"), 'w') as f:
        f.write(json.dumps(achievements))

    with open(os.path.join(out_dir, "supported_languages.txt"), 'w') as f:
        f.write("english\n")

    with open(os.path.join(out_dir, "steam_appid.txt"), 'w') as f:
        f.write(str(appid))

    dlc_list = get_dlc(appid)

    with open(os.path.join(out_dir, "DLC.txt"), 'w', encoding="utf-8") as f:
        f.write('\n'.join(dlc_list))