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

Installation
--------------

*New Script*
Install qbittorrent-cli
Install jq (JSON processor)

```bash
sudo apt update && sudo apt install -y jq
```
Clone qBitTorrent-Cleanup 

```bash
  git clone https://github.com/Jarsky/qBitTorrent-Cleanup-Script.git && chmod +x ./qBitTorrent-Cleanup-Script/qBitTorrent-Cleanup.sh
```

Configure defaults for qbittorrent-cli

```bash
qbt settings set url http://localhost:8000 #URL of qBitTorrent WebUI
qbt settings set username <username> #Only if you enabled user authentication
qbt settings set password <prompt> #Only if you enabled user authentication
```
Usage
--------------

### General
<br />
Edit the path to your downloads and qbittorrent.log in the script

`./qBitTorrent-Cleanup.sh --help` for supported commands
![image](https://user-images.githubusercontent.com/839416/213888478-98a670c2-a7c4-4832-b269-b6145d8b6929.png)


`./qBitTorrent-Cleanup.sh -legacy test` for log only (no deletion)
![image](https://user-images.githubusercontent.com/839416/213888450-af1fed66-2287-4a39-8f40-87b657ac5c54.png)


`./qBitTorrent-Cleanup.sh -legacy`
![image](https://user-images.githubusercontent.com/839416/213888378-cdc0f7ac-85b6-4913-a458-add55c50337a.png)




### CRON  
  
qBt-mover can setup CRON for you.  
Simply run `./qBitTorrent-Cleanup.sh -cron` which will give you the commands. 
![image](https://user-images.githubusercontent.com/839416/213888507-b6a4818d-1ab4-4c57-bc29-3cbd196ad441.png)


Setting up the default using **./qBitTorrent-Cleanup.sh -cron legacy** looks like below

![image](https://user-images.githubusercontent.com/839416/213888525-36a4b908-ddbf-4ad3-a489-8d31201f698e.png)

```bash
## qBitTorrent-Cleanup cron
* 4 * * *      cd /home/jarsky/scripts/qBitTorrent-Cleanup-Script && ./qBitTorrent-Cleanup.sh -legacy

```

If you want to remove the CRON entries just use

```bash
./qBitTorrent-Cleanup.sh -cron remove
```
![image](https://user-images.githubusercontent.com/839416/213888542-52335bc1-2b2f-42f7-9a31-7e24b8325df9.png)


### LOGGING

**Default:** /var/log/qBitTorrent-Cleanup.log

If you want to run the script as your user in this location, then:

```bash
sudo touch /var/log/qBitTorrent-Cleanup.log
sudo chmod 755 /var/log/qBitTorrent-Cleanup.log
```


It is good practice to configure a logrotate.  
In most GNU you would do something like this

```bash
sudo touch /etc/logrotate.d/qBitTorrent-Cleanup
sudo nano /etc/logrotate.d/qBitTorrent-Cleanup
```

And put the below code into the file and save

```bash
    /var/log/qBitTorrent-Cleanup.log {
            size 20M
            rotate 5
            compress
            delaycompress
            missingok
            notifempty
    }
```

**NOTE** You should set a larger size, as the script relies on the log for legacy function

This will let the log grow to 20 Megabytes, then rotate.  
It will rotate 5x and then delete the oldest.  
The log files from 2 onwards will be compressed.  

You can run do a dry-run by running this command

```bash
sudo logrotate -d /etc/logrotate.d/qBitTorrent-Cleanup
```
