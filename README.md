# qBitTorrent-Cleanup-Script
Script to cleanup unrar'd files after torrent automatically removed



Overview
-------------

Many torrent releases on private trackers are still in a .rar archive. For automation these need to be extracted. In qBitTorrent this can be done by using the external program with a command such as:

<code>unrar x "%F/*.r*" "%F/"</code>

When using a cleanup to automatically remove torrents, wether that be natively in [qBitTorrent](https://www.qbittorrent.org) or using a script such as [autoremove-torrents](https://github.com/jerrymakesjelly/autoremove-torrents) the UnRAR'd file and subsequently the sub folder are not removed.

If you're using other tools such as Sonarr, Radarr, Lidarr, etc...which automatically copy your files, and the extracted files are left in a temporary location then this isnt ideal.

This script will scrub the qBitTorrent log and delete leftover files.

![image](https://user-images.githubusercontent.com/839416/164169490-057b945a-fc38-4c4b-9388-901f31dec32c.png)


Usage
--------------

1. Download the script.
2. Install TS (apt install moreutils)
3. Set your paths in the configuration
4. Setup a cronjob to automate this script
<br />
e.g to set a cronjob as root run <code>sudo crontab -e</code> and create a cron entry
<br /><br />
<blockquote>
  #qBitTorrent Cleanup CRON Job  
  <br>
  * 4 * * * /path/to/scripts/qBitTorrent-Cleanup.sh  
</blockquote>
<br />
**The CRON user will need Read access to the qBitTorrent logs, and write to the Cleanup script log file**
<br />
## NOTE: No action will be taken unless you set "deleteFiles="true" 

Known Issues
---------------

Sometimes the log gets spammed for some reason.   
Delete qBittorrent-Cleanup.log and it should behave itself properly again.
