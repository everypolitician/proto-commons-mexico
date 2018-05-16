require 'json'
require 'open-uri'
require 'csv'
require 'cgi'


WIKIDATA_PATH = "https://www.wikidata.org/wiki/Special:EntityData/"

def check_item(expected, item_id, langs)
  labels = item_labels(item_id, langs)
  unless labels.include? expected.strip.downcase
    puts "WARNING: #{expected} was #{labels} (#{item_id})"
  end
end

def item_labels(item_id, langs)
  wikidata_json =  JSON.parse(open(WIKIDATA_PATH + item_id).read)
  labels = []
  langs.each do |lang|
    if wikidata_json["entities"][item_id]["labels"].has_key?(lang)
      labels << wikidata_json["entities"][item_id]["labels"][lang]["value"].downcase
    end
  end
  labels
end


def item_claim_target(item_id, claim_id, qualifier_id=nil)
  wikidata_json =  JSON.parse(open(WIKIDATA_PATH + item_id).read)

  if wikidata_json["entities"][item_id]["claims"].has_key? claim_id
    if qualifier_id
      # puts wikidata_json["entities"][item_id]["claims"][claim_id].first
      wikidata_json['entities'][item_id]["claims"][claim_id].each do |claim|
        if claim.has_key?('qualifiers') && claim['qualifiers'].has_key?(qualifier_id)
          return claim['qualifiers'][qualifier_id].first["datavalue"]["value"]["id"]
        end
      end
      raise "no #{qualifier_id} on #{claim_id} claim for #{item_id}"
    else
      return wikidata_json["entities"][item_id]["claims"][claim_id].first['mainsnak']['datavalue']['value']['id']
    end
  else
    raise "no #{claim_id} claim for #{item_id}"
  end
end

def check_executive(langs)
  puts "executive/index.json"

  json = JSON.parse(File.open("executive/index.json").read)
  json.each do |element|
    check_item(element["comment"], element["executive_item_id"], langs)
    element["positions"].each do |position|
      check_item(position["comment"], position["position_item_id"], langs)
    end
  end
  nil
end

def check_legislative(langs)
  puts "legislative/index.json"

  json = JSON.parse(File.open("legislative/index.json").read)

  json.each do |element|
    check_item(element["comment"], element["house_item_id"], langs)
    puts "Legislature: #{element["comment"]}"
    puts "Membership wikidata labels: #{item_labels(element['position_item_id'], langs)}"
    puts ''
  end
  nil
end

def check_boundaries(langs)
  puts "boundaries/index.json"

  json = JSON.parse(File.open("boundaries/index.json").read)

  json.each do |element|
    if element["associations"]
      element["associations"].each do |association|
        check_item(association["comment"], association["position_item_id"], langs)
        if element['area_type_wikidata_item_id']
          puts "Directory: #{element["directory"]}"
          puts "Area wikidata labels: #{item_labels(element['area_type_wikidata_item_id'], langs)}, Position label #{association["comment"]}"
        end
      end
    end
    puts ''
  end
  nil
end

def create_executive_index_entries(query_csv_file)
  entries = []

  CSV.read(query_csv_file, headers: true, header_converters: :symbol, converters: nil).map(&:to_h).map do |row|
    entry = {}
    entry["comment"] = row[:councillabel]
    entry["executive_item_id"] = row[:council].split("/").last
    entry["positions"] = []
    entry["positions"] << {"comment" => row[:positionlabel],
                           "position_item_id" => row[:position].split("/").last }
    entries << entry
  end

  File.open("index.json", 'w') { |f| f.write(JSON.pretty_generate(entries)) }
end

def create_boundaries_index_entries(boundaries_dir_name)
  entries = []
  seen_parents = []
  CSV.read("boundaries/build/#{boundaries_dir_name}/#{boundaries_dir_name}.csv", headers: true, header_converters: :symbol, converters: nil).map(&:to_h).map do |row|
    entry = {}
    puts row.inspect
    unless seen_parents.include? row[:ms_fb_pare]
      entry["directory"] = boundaries_dir_name
      constituency_wikidata_id = row[:wikidata].split("/").last
      area_type_wikidata_item_id = item_claim_target(constituency_wikidata_id, 'P31')
      entry["area_type_wikidata_item_id"] = area_type_wikidata_item_id
      legislative_item_id = item_claim_target(area_type_wikidata_item_id, 'P279', 'P642')
      legislative_position_id = item_claim_target(legislative_item_id, 'P527')
      jurisdiction = item_claim_target(legislative_item_id, 'P1001')
      # executive_position_id = item_claim_target(jurisdiction, 'P1313')
      # executive_item_id = item_claim_target(executive_position_id, 'P361')
      entry["associations"] = [
                                {
                                  "comment": item_labels(legislative_position_id, ['en', 'es']).first,
                                  "position_item_id": legislative_position_id
                                }
                              ]
      entry["name_columns"] = { "en": "label_en",
                                "es": "label_es" }
      entry["filter"] = {
                          "match": row[:ms_fb_pare],
                          "column": "MS_FB_PARE"
                        }
      entries << entry
      seen_parents << row[:ms_fb_pare]
    end
  end
  File.open("index.json", 'w') { |f| f.write(JSON.pretty_generate(entries)) }
end


def current_legislative_term(legislature_item_id)
  query = "SELECT ?term  ?legislature ?termLabel ?legislatureLabel ?series WHERE {
?term wdt:P31 wd:Q15238777;
p:P31 ?instanceStatement.
?instanceStatement pq:P642 wd:#{legislature_item_id}.
?instanceStatement pq:P1545 ?series
SERVICE wikibase:label { bd:serviceParam wikibase:language \"en\". }
}
ORDER BY DESC(?series)
LIMIT 1"
  response_json = open('https://query.wikidata.org/sparql?query=' + CGI.escape(query) + '&format=json')
  JSON.parse(response_json.read)['results']['bindings'].first["term"]["value"].split("/").last
end

def create_legislature_index_entries(boundaries_dir_name, langs)
  entries = []
  seen_parents = []
  CSV.read("boundaries/#{boundaries_dir_name}/#{boundaries_dir_name}.csv", headers: true, header_converters: :symbol, converters: nil).map(&:to_h).map do |row|
    entry = {}
    puts row.inspect
    unless seen_parents.include? row[:ms_fb_pare]
      constituency_wikidata_id = row[:wikidata].split("/").last
      area_type_wikidata_item_id = item_claim_target(constituency_wikidata_id, 'P31')

      wikidata_json =  JSON.parse(open(WIKIDATA_PATH + area_type_wikidata_item_id).read)
      legislature_item_id = item_claim_target(area_type_wikidata_item_id, 'P279', 'P642')
      position_id = item_claim_target(legislature_item_id, 'P527')
      entry["comment"] =  item_labels(legislature_item_id, langs).first
      entry["house_item_id"] = legislature_item_id
      entry["position_item_id"] = position_id
      entry["terms"] = [
        {
            "term_item_id": current_legislative_term(legislature_item_id)
        }
      ]
      entries << entry
      seen_parents << row[:ms_fb_pare]
    end
  end
  File.open("index.json", 'w') { |f| f.write(JSON.pretty_generate(entries)) }

end

def find_missing_labels(lang)
  ['legislative', 'executive'].each do |branch|
    missing = { 'persons': [],
                'organizations': [],
                'areas': []}

    Dir.glob("**/popolo-m17n.json").each do |file|

      data = JSON.parse(File.read file)

      data['persons'].each do |person|
        unless person['name']["lang:#{lang}"]
          missing[:'persons'] << person['id']
        end
      end
      data['organizations'].each do |organization|
        unless organization['name']["lang:#{lang}"]
          missing[:'organizations'] << organization['id']
        end
      end
      data['areas'].each do |area|
        unless area['name']["lang:#{lang}"]
          missing[:'areas'] << area['id']
        end
      end
    end

    puts missing.inspect
    missing.keys.each do |key|
      puts key
      missing[key].each do |item|
        puts "#{item} #{item_labels['en_US']}"
      end
    end
  end
end


create_boundaries_index_entries 'local-electoral-districts'
