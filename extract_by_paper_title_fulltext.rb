# coding: utf-8
require 'sanitize'
require 'json'
require 'zlib'
require 'cgi'
require 'htmlentities'
require 'time'

def str_normalize(str)
  if str.nil? == false
    str.scrub!('')
    str = CGI.unescape(str)
    str.scrub!('')
    str = CGI.unescapeHTML(str)
    str.scrub!('')
    str = HTMLEntities.new.decode(str)
    str.scrub!('')
    str = str.downcase

    str.gsub!("'", '')
    str.gsub!('"' , '')
    str.gsub!('‘', '')
    str.gsub!("\\", '')
    str.gsub!('[', '')
    str.gsub!(']', '')
    str.gsub!('?', '')
    str.gsub!('!', '')
    str.gsub!(',', ' ')
    str.gsub!('.', ' ')
    str.gsub!('-', ' ')
    str.gsub!('—'' ')
    str.gsub!('—', '')
    str.gsub!('–', '')
    str.gsub!('“', '')
    str.gsub!('”', '')
    str.gsub!('’', '')
    str.gsub!(':', '')
    str.gsub!('_', ' ')
    str.gsub!(/[[:space:]]/, ' ')
    str.gsub!("\n", ' ')
    str.gsub!("\t", ' ')
    str.gsub!(/\s+/, ' ')
    str.gsub!(/^\s+/, '')
    str.gsub!(/\s+$/, '')
  end
  return str
end

def remove_spc(str)
  str.gsub!(/\s/, '')
  return str
end


puts "START\t#{Time.now}\t$ ruby #{__FILE__}"

Dir.glob('./baselist/*.json.gz').sort.each{|filepath|

  outpath = filepath.dup
  outpath.sub!('./baselist/', './result/')
  outpath.sub!('.json.gz', '_paper_title_fulltext.json.gz')

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
    dic[doi]['meta']['page_id'] = page_id
    dic[doi]['meta']['page_title'] = page_title
    dic[doi]['info'] = Hash.new
    dic[doi]['matched'] = Hash.new

    paper_title = raw['doi_list'][doi]['paper_title']
    dic[doi]['info']['raw_paper_title_full'] = str_normalize(paper_title)
    dic[doi]['info']['raw_paper_title_first5words'] = dic[doi]['info']['raw_paper_title_full'].split(' ')[0,5].join(' ')
    dic[doi]['info']['remove_spc_paper_title_full'] = remove_spc(dic[doi]['info']['raw_paper_title_full'].dup)
    dic[doi]['info']['remove_spc_paper_title_first5words'] = remove_spc(dic[doi]['info']['raw_paper_title_first5words'].dup)
  }


  i = 0
  max = Zlib::GzipReader.open(filepath_revision).read.count("\n")

  Zlib::GzipReader.open(filepath_revision){|file|
    while line = file.gets
      if dic['status'].values.include?(false) == true
        line.chomp!
        i += 1

        puts "#{Time.now}\t#{i}/#{max}\t#{page_id}\t#{page_title}"
        
        tmp = JSON.load(line)
        text = str_normalize(tmp['text'])
        text = remove_spc(text)

        dic['status'].each{|doi, f|
          if f == false
            flag_matched = false
            title_full = dic[doi]['info']['remove_spc_paper_title_full']
            title_first5words = dic[doi]['info']['remove_spc_paper_title_first5words']

            if text.include?(title_full) == true
              flag_matched = true
              dic[doi]['matched']['paper_title_full'] = true
            end

            if text.include?(title_first5words) == true
              flag_matched = true
              dic[doi]['matched']['paper_title_first5words'] = true
            end

            if flag_matched == true
              dic['status'][doi] = true
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
  puts dic.to_json
  Zlib::GzipWriter.open(outpath){|outfile|
    outfile.puts JSON.pretty_generate(dic)
  }
}

puts "END\t#{Time.now}\t$ ruby #{__FILE__}"
