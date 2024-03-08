import requests
import shodan
import csv

key = "" #Add you key here


api = shodan.Shodan(key)

Server_Type = input("What Server are you looking for? ")

# URL for gathering data on assets and their settings
url = "https://api.shodan.io/shodan/alert/info?key=" + key

# Execute the query to pull the results
response = requests.get(url)
alerts = response.json()

# Create a CSV file (if it doesn't exist) or append to an existing one
csv_filename = "server-"+Server_Type+".csv"
with open(csv_filename, mode="a", newline="") as csvfile:
    fieldnames = ["name", "alert_id", "Subnet", "ipaddress", "server_type", "P3P"]
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)

    # Check if the file is empty (no header row)
    if csvfile.tell() == 0:
        writer.writeheader()

    # Process the alerts and write data to CSV
    for alert in alerts:
        name = alert["name"]
        alert_id = alert["id"]
        ip_filter = alert["filters"]["ip"]

        print (f"Processing {name}")

        for subnet in ip_filter:
            results = api.search(f"{Server_Type} net:{subnet}")
            matches = results["matches"]

            # Display information about each result
            for result in matches:
                ip_address = result["ip_str"]
                server_info = result["data"]

                # Extract the server field
                server_lines = server_info.split("\n")
                for line in server_lines:
                    if line.startswith("Server:"):
                        server_field = line.strip()
                        break
                else:
                    server_field = "N/A"

                for line in server_lines:
                    if line.startswith("P3P:"):
                        P3P_field = line.strip()
                        break
                else:
                    P3P_field = "N/A"

                # Write data to CSV
                writer.writerow({
                    "name": name,
                    "alert_id": alert_id,
                    "Subnet": subnet,
                    "ipaddress": ip_address,
                    "server_type": server_field,
                    "P3P": P3P_field
                })

print(f"Data has been saved to {csv_filename}")