![pansift_social_v37](https://user-images.githubusercontent.com/4045949/153039199-940a88e8-1a62-4d78-9c74-48094f541336.jpg)

# Intro 

Pansift is a macOS troubleshooting and monitoring tool with a focus on the network. It is for those who support others **remotely** and enables them to rapidly find and fix issues (especially WiFi related). Whether you are a family member doing Zoom calls, a developer, a salesperson, or a gamer who can't afford to be disconnected, interrupted, or slowed down, Pansift makes the invisible visible for a quick fix.

Pansift is about helping others to avoid stress and stay productive with optimally functioning tools and networks. It's about saving you time, maintaining situational awareness, and getting to root causes quickly, easily, and **remotely** (even for historical issues). Whether it's for WiFi, DNS, IPv4, IPv6, or simple disk utilization issues - PanSift allows you to keep an eye on multiple remote machines (just like server monitoring) only with a more lightweight, heavily wireless focused, and user-friendly footprint. More info: [https://pansift.com](https://pansift.com) 
 
## Attended Installs

**Download [Pansift DMG](https://github.com/pansift/p3/raw/main/Pansift.dmg), open it, and drag `Pansift.app` to the `Applications` folder and double click to run or use Command+O to open.**

You can then claim your agent from the options in the menubar or manually in the web application (using the bucket UUID code). Claiming will require you to register an account at [https://pansift.com](https://app.pansift.com/demo/logout_demo) to view your data and insights. Happy troubleshooting!

## Unattended Installs

### Manual Claim

You can use the [unattended_install.sh](Scripts/unattended_install.sh) script to do a 'hands-off' install on a remote machine. This will provision a new bucket automatically which will need to be manually claimed (UUID will need to be communicated for a remote claim) unless you use the [automatic claim](https://github.com/pansift/p3#automatic-claim--multiagent) method.

> :warning: **You must run the script as the logged in user you with to monitor and not with a headless system or service account.**

Pre-position the `Pansift.app` bundle from the [Pansift.dmg](Pansift.dmg) file in a directory on the remote machine (**not** the `/Application` directory, but your preferred staging directory, as the script will then copy the files to `/Applications` and `~Library` etc). 

The script will then start the application in the current context, so it expects a full session (GUI and the correct user). PanSift, once running, will **not** automatically claim a bucket or register an account, but it will initiate the ZTP (Zero Touch Provisioning) process, and start writing metrics to a remote bucket. You can then claim the bucket from the agent or via the web based claim using the PanSift/bucket UUID. 

Example Usage: `./unattended_install.sh /tmp/Pansift.app 2>&1 | tee pansift_install.log` 

**Note:** The ZTP process remotely provisions buckets to a special holding account until claimed. It gets a write token and is told which remote URL to send data to for ingestion. If you want to specify the bucket, token, and URL **in advance**, please see the next section.


### Automatic Claim / Multiagent

This section details how to use the [unattended_install.sh](Scripts/unattended_install.sh) script to do a 'hands-off' install on a remote machine *with specific configuration for an existing bucket*. This method prevents the ZTP process from running and allows you to specify settings in advance so agents report to an already created bucket. It requires staging the [Pansift.dmg](Pansift.dmg) file as above but also includes `3` additional configuration files.

> :information_source: Buckets form one boundary for account based reads and agent writes. Buckets also define the test host records used by DNS, HTTP, and traces for all the agents in the bucket. Please consider what agents you want to report in to what buckets. Multiagent buckets allow you to administer a group of agents rather than the default 1-1 agent to bucket mapping.

> :warning: **You must run the script as the logged in user you with to monitor and not with a headless system or service account.**

You can pre-stage populated `pansift_uuid.conf`, `pansift_token.conf`, and `pansift_ingest.conf` files (in the same staging directory as the downloaded or pre-positioned `Pansift.app`). PanSift then recognizes it has a full configuration and uses an existing *claimed* bucket without any additional provisioning process (other than an agent sync in the web dashboard). This is useful for mass-deployments to machines you have access to remotely via MDM (Mobile Device Management) or other orchestration software. 

1. Please remember that you must run the script as the user account you intend to implement RUM (Real User Monitoring) on and you must also have a full window session.
2. If you do not have an existing bucket but you wish to use one for multiple agents (or want extra buckets for greater separation of agents) please [contact support](https://pansift.com/contact) for the *simple steps* to create a new 'holding' bucket including the requisite UUID, token, and URL. You can use an existing bucket if you have claimed one already.
3. For **commercial customers** please [contact support](https://pansift.com/contact) if you want to ensure your bucket and data resides in the Influx cloud rather than our Influx OSS instances.

#### Agent Configuration Files For Pre-staging

 * `pansift_uuid.conf` contains a single string comprised of a UUIDv4 value e.g. `84b878ec-da07-490e-8375-c36dfbb098fa`. This is actually the bucket UUID that you want the agent to writes to. This bucket UUID is available from your account. If you have not claimed any buckets yet or wish to use a totally new bucket then please [contact support](https://pansift.com/contact)

 * `pansift_token.conf` contains a single string comprised of an 86 character hexadecimal string ending in a double equals "==" (so it's 88 characters long). This is a write token for the bucket and can be used by the agents you deploy it to. [Contact support](https://pansift.com/contact) if you are using a "multiagent" bucket and want discrete tokens per agent rather than creating more buckets.

 * `pansift_ingest.conf` contains a single string comprised of a fully qualified URL for the bucket's datastore and ingest host. It takes the form of the `pansift`/`bucket` UUID as the host portion in the `ingest` subdomain. A URL example would be as such; `https://84b878ec-da07-490e-8375-c36dfbb098fa.ingest.pansift.com` (but replace with your UUID) and it needs to resolve in DNS before writes will succeed. This URL tells the agent which datastore host to speak to. The DNS entry is created during the normal ZTP process or by support so please liaise with support for mass deployments. Please check the PanSift log for an agent or [contact support](https://pansift.com/contact) if this is not resloving for you. It is a CNAME to the datastore A record.

> :warning: **Do not configure the `pansift_ingest.conf` datastore URL with the A record. Use "https://" + the CNAME which follows the pattern of `https://<uuid>.ingest.pansift.com`** otherwise backend operational changes may cause interruptions to your agents ability to write.
