# qBitTorrent-Cleanup-Script
Script to cleanup unrar'd files after torrent automatically removed



Overview
-------------

Many torrent releases on private trackers are still in a .rar archive.<br />
For automation these need to be extracted. In qBitTorrent this can be done <br />
by using the external program with a command such as:<br />

<code>unrar x "%F/*.r*" "%F/"</code>

When using a cleanup to automatically remove torrents, wether that be<br />
natively in qBitTorrent or using a script such as autoremove-torrents<br />
the UnRAR'd file and subsequently the sub folder are not removed.<br />

If you're using other tools such as Sonarr, Radarr, Lidarr, etc...which<br />
automatically copy your files, and the extracted files are left in a<br />
temporary location then this isnt ideal.<br />

This script will scrub the qBitTorrent log and delete leftover files.

Usage
--------------

1. Download the script.
2. Install TS (apt install moreutils)
3. Set your paths in the configuration
4. Setup a cronjob to automate this script
<br />
e.g to set the cronjob as root<br />
<code>sudo crontab -e<code><br />
<br />
<br />
<pre>
#qBitTorrent Cleanup CRON Job
* 1 * * * /path/to/scripts/qBitTorrent-Cleanup.sh
</pre>
<br />
### The CRON user will need Read access to the qBitTorrent logs, and write to the Cleanup script log file
<br />
