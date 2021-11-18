require 'cgi'
require 'json'
require 'time'
require 'zlib'

def str_normalize(raw)
  result = raw.dup

  if result.nil? == false
    result.scrub!('')
    result = CGI.unescape(result)
    result.scrub!('')
    result = result.downcase
  end

  return result
end


puts "START\t#{Time.now}\t$ ruby #{__FILE__}"

Dir.glob('./baselist/*.json.gz').sort.each{|filepath|
  outpath = filepath.dup
  outpath.sub!('./baselist/', './result/')
  outpath.sub!('.json.gz', '_identifiers.json.gz')

  raw = JSON.load(Zlib::GzipReader.open(filepath).read)

  page_id = raw['page_id']
  page_title = raw['page_title']

  filepath_revision = "./revision/#{page_id}.json.gz"
  if File.exist?(filepath_revision) == false
    raise "Error::FileNotFound\tfilepath_revision\t#{filepath_revision}"
  end
  
  dic = Hash.new


  dic['status'] = Hash.new
  raw['doi_list'].keys.each{|doi|
    dic['status'][doi] = false
    dic[doi] = Hash.new
    dic[doi]['meta'] = Hash.new
    dic[doi]['identifier'] = Hash.new
    dic[doi]['meta']['page_id'] = page_id
    dic[doi]['meta']['page_title'] = page_title
  }

  i = 0
  max = Zlib::GzipReader.open(filepath_revision).read.count("\n")

  Zlib::GzipReader.open(filepath_revision){|file|
    while line = file.gets
      if dic['status'].values.include?(false) == true
        line.chomp!
        i += 1
        
        tmp = JSON.load(line)
        text = str_normalize(tmp['text'])
        
        puts "#{Time.now}\t#{i}/#{max}\t#{page_id}\t#{page_title}"

        dic['status'].each{|doi, f|
          if f == false
            flag_matched = false
            raw['doi_list'][doi].each{|k,v|
              if k != 'paper_title'
                if v.class == String
                  if text.include?(v) == true
                    flag_matched = true
                    dic['status'][doi] = true
                    dic[doi]['identifier'][k] = v
                  end
                elsif v.class == Array
                  v.each{|item|
                    if text.include?(item) == true
                      dic['status'][doi] = true
                      flag_matched = true
                      if dic[doi]['identifier'].has_key?(k) == false
                        dic[doi]['identifier'][k] = Array.new
                      end
                      dic[doi]['identifier'][k].push(item)
                    end
                  }
                end
              end
            }

            if flag_matched == true
              dic[doi]['meta']['revision_id'] = tmp['revid']
              dic[doi]['meta']['revision_timestamp'] = Time.parse(tmp['timestamp']).to_s
              dic[doi]['meta']['revision_comment'] = tmp['comment']
              dic[doi]['meta']['editor_name'] = tmp['username']
              dic[doi]['meta']['editor_anonymous'] = tmp['anonymous']
            end
          end
        }

      else
        break
      end
    end
    file.close
  }

  dic.delete('status')

  Zlib::GzipWriter.open(outpath){|outfile|
    puts dic.to_json
    outfile.puts JSON.pretty_generate(dic)
    outfile.close
  }
}

puts "END\t#{Time.now}\t$ ruby #{__FILE__}"
