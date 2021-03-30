require 'net/http'
require 'json'

#-----------------------------------------------------------------------------
# * Helper Methods
#----------------------------------------------------------------------------

def extract_timestamp(log_url, hour, minute)
  log_url.scan(/log=(\d+)/) { |match|
    tenhou_timestamp = match[0]

    year = tenhou_timestamp[0...4]
    month = tenhou_timestamp[4...6]
    day = tenhou_timestamp[6...8]

    return Time.new(year=year, month=month, day=day, hour=hour, minute=minute)
  }
end

#==============================================================================
# ** Main
#==============================================================================

hanchan_map = {}

Dir.glob("logs/*").each { |filename|
  next if not filename[/scc2019/]
  month = filename[12...14]

  hanchan_map[month] ||= []
  hanchan_map[month].push(filename)
}

hanchan_map.keys.each { |month|
  hanchan_list = []
  
  hanchan_map[month].each { |filename|
    File.open("#{filename}", 'r') { |f|
      body = f.read

      body.split("<br>").each { |line|
        next if not line["四鳳南喰赤"]

        log_url = line.match(/"(http:\/\/tenhou.net.+)"/)[1]

        hour, minute = line.split("|")[0].strip.split(":").map { |s| s.to_i }
        timestamp = extract_timestamp(log_url, hour, minute)

        usernames = line.split("|")[-1].split(" ").map { |s| s.gsub(/\([+-]?\d+\.\d\)/) { "" } }

        hanchan_blob = {
          log_url: log_url,
          timestamp: timestamp,
          usernames: usernames,
        }

        hanchan_list.push(hanchan_blob)
      }
    }
  }

  File.open("#{month}.json", 'w') { |f|
    f.write({ list: hanchan_list }.to_json)
  }

  p "Finished processing month: #{month}"
}

