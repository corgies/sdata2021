# coding: utf-8
require 'sanitize'
require 'json'
require 'zlib'
require 'cgi'
require 'levenshtein'
require 'htmlentities'
require 'time'

@cond_threshold = 0.2
@dic_levenshtein = Hash.new

def str_normalize(str)
  result = str.dup

  if result.nil? == false
    result.scrub!('')
    result = CGI.unescape(result)
    result.scrub!('')
    result = CGI.unescapeHTML(result)
    result.scrub!('')
    result = HTMLEntities.new.decode(result)
    result.scrub!('')
    result = result.downcase

    result.gsub!("'", '')
    result.gsub!('"' , '')
    result.gsub!('[', '')
    result.gsub!(']', '')
    result.gsub!('?', '')
    result.gsub!('!', '')
    result.gsub!(',', ' ')
    result.gsub!('.', ' ')
    result.gsub!('-', ' ')
    result.gsub!('—'' ')
    result.gsub!('—', '')
    result.gsub!('“', '')
    result.gsub!('”', '')
    result.gsub!('’', '')
    result.gsub!(':', '')
    result.gsub!('_', ' ')
    result.gsub!("\n", '')
    result.gsub!("\t", ' ')
  end

  return result
end

def remove_spc(str)
  str.gsub!(/\s/, '')
  return str
end

def str_normalize_for_sim(str)
  result = str.dup
  result = str_normalize(result)
  result = remove_spc(result)
  return result
end

def calc_similarity(wp_title, dic, tmp, tag)
  normalized_wp_title = str_normalize_for_sim(wp_title)

  if normalized_wp_title.nil? == false
    dic['status'].keys.each{|doi|
      if dic['status'][doi] == false
        paper_title = dic[doi]['info']['raw_paper_title_full']
        normalized_paper_title = str_normalize_for_sim(paper_title.dup)
        
        if normalized_paper_title.nil? == false

          key = "#{normalized_paper_title}\t#{normalized_wp_title}"
          if @dic_levenshtein.has_key?(key) == false
            length = [normalized_paper_title.length, normalized_wp_title.length].max
            score_raw = Levenshtein.distance(normalized_paper_title, normalized_wp_title)
            score = score_raw.to_f/length.to_f
            @dic_levenshtein[key] = score
            if score <= @cond_threshold
              dic['status'][doi] = true
              dic[doi]['info']['sim_threshold'] = @cond_threshold
              dic[doi]['info']['normalized_paper_title'] = normalized_paper_title
              dic[doi]['info']['normalized_wp_title'] = normalized_wp_title
              dic[doi]['info']['title_length'] = length
              dic[doi]['info']['score_raw'] = score_raw
              dic[doi]['info']['score'] = score
              dic[doi]['info']['tag'] = tag
              dic[doi]['meta']['revision_id'] = tmp['revid']
              dic[doi]['meta']['revision_timestamp'] = Time.parse(tmp['timestamp']).to_s
              dic[doi]['meta']['revision_comment'] = tmp['comment']
              dic[doi]['meta']['editor_name'] = tmp['username']
              dic[doi]['meta']['editor_anonymous'] = tmp['anonymous']
            end
          end
        end
        
      end
    }
  end
end


puts "START\t#{Time.now}\t$ ruby #{__FILE__}"

Dir.glob('./baselist/*.json.gz').sort.each{|filepath|

  outpath = filepath.dup
  outpath.sub!('./baselist/', './result/')
  outpath.sub!('.json.gz', '_paper_title_similarity.json.gz')

  raw = JSON.load(Zlib::GzipReader.open(filepath).read)

  page_id = raw['page_id']
  page_title = raw['page_title']

  filepath_ref_and_cites = "./revision/#{page_id}_ref_and_cites.json.gz"
  if File.exist?(filepath_ref_and_cites) == false
    raise "Error::FileNotFound\tfilepath_ref_and_cites\t#{filepath_ref_and_cites}"
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
    paper_title = raw['doi_list'][doi]['paper_title']
    dic[doi]['info']['raw_paper_title_full'] = str_normalize(paper_title)
  }

  i = 0
  max = Zlib::GzipReader.open(filepath_ref_and_cites).read.count("\n")

  Zlib::GzipReader.open(filepath_ref_and_cites){|file|
    while line = file.gets
      if dic['status'].values.include?(false) == true
        line.chomp!
        i += 1
        puts "#{Time.now}\t#{i}/#{max}\t#{page_id}\t#{page_title}"
        
        tmp = JSON.load(line)

        if tmp['refs'].empty? == false
          tmp['refs'].each{|item|
            if item['wikitext_title'].nil? == false
              wp_title = item['wikitext_title']
              original_text = item['original_text']
              sim = calc_similarity(wp_title, dic, tmp, original_text)
            end

            if item['parscit_title'].nil? == false
              wp_title = item['parscit_title']
              original_text = item['original_text']
              sim = calc_similarity(wp_title, dic, tmp, original_text)
            end
          }
        end

        if tmp['template_cites'] == false
          tmp['template_cites'].each{|item|
            if item['wikitext_title'].nil? == false
              wp_title = item['wikitext_title']
              original_text = item['original_text']
              sim = calc_similarity(wp_title, dic, tmp, original_text)
            end

            if item['parscit_title'].nil? == false
              wp_title = item['parscit_title']
              original_text = item['original_text']
              sim = calc_similarity(wp_title, dic, tmp, original_text)
            end
          }
        end

      else
        break
      end
    end
    file.close
  }

  dic.delete('status')
  Zlib::GzipWriter.open(outpath){|outfile|
    outfile.puts JSON.pretty_generate(dic)
    outfile.close
  }
  puts dic.to_json
}

puts "END\t#{Time.now}\t$ ruby #{__FILE__}"
