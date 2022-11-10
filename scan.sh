#!/bin/bash 
mkdir scope scans
# set vars 
figlet Bash-Heist
id="$1"
ppath="$(pwd)"
scope_path="$ppath/scope/$id"

timestamp="$(date +%s)"
scan_path="$ppath/scans/$id-$timestamp"

if [ ! -d "$scope_path" ]; then
	mkdir "$ppath/scope/$id" | echo "$id" >> roots.txt | mv roots.txt "$scope_path/"
fi

mkdir -p "$scan_path"
cd "$scan_path"

### Perform scan ### 
echo "Starting scan against roots:"
cat "$scope_path/roots.txt"
cp -v "$scope_path/roots.txt" "$scan_path/roots.txt"
sleep 3

end_time=$(date +%s)
seconds="$(expr $end_time - $timestamp)"
time=""

if [[ "$seconds" -gt 59 ]]
then
	minutes=$(expr $seconds / 60)
	time="$minutes minutes"
else
	time="$seconds seconds"
fi

echo "Scan $id took $time"

## Perform Scan ##

echo "Starting Full Recon Scan Against : "
cat "$scope_path/roots.txt"
cp -v "$scope_path/roots.txt" "$scan_path/roots.txt"

#DNS Bruteforcing 
cat "$scan_path/roots.txt" | subfinder | anew subs.txt
cat "$scan_path/roots.txt" | shuffledns -w "$ppath/lists/pry-dns.txt" -r "$ppath/lists/resolvers.txt" | anew subs.txt

# DNS Enumeration - Find Subdomains 
cat "$scan_path/roots.txt" | haktrails subdomains | anew subs.txt | wc -l
cat "$scan_path/roots.txt" | subfinder | anew subs.txt | wc -l 
cat "$scan_path/roots.txt" | shuffledns -w "$ppath/lists/pry-dns.txt" -r "$ppath/lists/resolvers.txt" | anew subs.txt | wc -l 

# DNS Resolution - Find Subdomains 
puredns resolve "$scan_path/subs.txt" -r "$ppath/lists/resolvers.txt" -w "$scan_path/resolved.txt" | wc -l 
dnsx -l "$scan_path/resolved.txt" -json -o "$scan_path/dns.json" | jq -r '.a?[]?' | anew "$scan_path/ips.txt" | wc -l

#Port Scanning & HTTP Server Discovery 

nmap -T4 -vv -iL "$scan_path/ips.txt" --top-ports 3000 -n --open -oX "$scan_path/nmap.xml"
tew -x "$scan_path/nmap.xml" -dnsx "$scan_path/dns.json" --vhost -o "$scan_path/hostport.txt" | httpx -sr -srd "$scan_path/responses" -json -o "$scan_path/http.json"

cat "$scan_path/http.json" | jq -r '.url' | sed -e "s/:80$//g" -e 's/:443$//g' | sort -u > "$scan_path/http.txt"

#Crawling

gospider -S "$scan_path/http.txt" --json | grep "{" | jq -r '.output?' | tee "$scan_path/crawl.txt" 

#Javascript Pulling
cat "$scan_path/crawl.txt" | grep "\.js" | httpx -sr -srd js





